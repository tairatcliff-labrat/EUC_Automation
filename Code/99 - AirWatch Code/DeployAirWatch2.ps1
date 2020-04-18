# File: DeployAirWatch2.ps1
# Installs AirWatch using the headless installer.
# PowerShell 4
# Chas Berndt

# Suppress errors. Leave the below line commented out for now.
#$ErrorActionPreference = "SilentlyContinue"

Write-Host "=============="
Write-Host "DeployAirWatch"
Write-Host "=============="

# Checking for PowerShell 4+
if ($PsVersionTable.PSVersion.Major -lt 4)
{
	Write-Host "This script requires a MINIMUM of PowerShell 4. Cannot continue."
	Exit 1
}

# Check arg count.
if ($Args.count -eq 6 -and $Args[0] -ne 0)
{
	[int]$RunMode = $Args[0]
	$ServerFqdn = $Args[1]
	$CnUrl = $Args[2]
	$DsUrl = $CnUrl
	$DbServer = $Args[3]
	$DbSchema = $Args[4]
	$DbUser = $Args[5]
	Write-Host "Six arguments provided. Using $CnUrl as the CN and DS URL."
}
elseif ($Args.count -eq 7 -and $Args[0] -ne 0)
{
	[int]$RunMode = $Args[0]
	$ServerFqdn = $Args[1]
	$CnUrl = $Args[2]
	$DsUrl = $Args[3]
	$DbServer = $Args[4]
	$DbSchema = $Args[5]
	$DbUser = $Args[6]
	Write-Host "Seven arguments provided. Using $CnUrl as the console URL and $DsUrl as the DS URL."
}
elseif ($Args.count -eq 2 -and $Args[0] -eq 0)
{
	[int]$RunMode = $Args[0]
	$ServerFqdn = $Args[1]
}
else
{
	Write-Error "You must provide six or seven arguments: RunMode, ServerFqdn, CnUrl, DsUrl (optional), DBServer, DBName, and DBUser. See documentation for more details."
	Exit 4
}

# If needed, try to import Posh-SSH
if ($RunMode -eq 10)
{
	try
	{
		Import-Module Posh-SSH
	}
	catch
	{
		Write-Host "Failed to import Posh-SSH. It might not be installed. Cannot continue."
		Write-Host "Exception: $_"
		DeployExit $Session 6
	}
}
# Determine working directory.
$WorkingDirectory = Split-Path $script:MyInvocation.MyCommand.Path

# Don't modify these!
$ServerUser = "awsso\svcautodeploy"
$ServerPass = "Ucantcm3!"
$InstallDir = "E:\AirWatch\"
$DbPass = "A1rWatchAdm1n"
$DbSaUser = "svcautodeploy"
$DbSaPass = "Ucantcm3"
$DbInstallerSearchString = "AirWatch_DB_*"
$AppInstallerSearchString = "AirWatch_Application_*"
$backupScriptPath = $WorkingDirectory + "\BackupDatabase.sql"
$resetRoleAndOgPath = $WorkingDirectory + "\ResetAdminUserRoleAndOG.sql"
$copyDatabaseScriptPath = $WorkingDirectory + "\ReplaceIntegrationDbWithGoldenDb.sql"
$restoreDbScriptPath = $WorkingDirectory + "\RestoreDatabase.sql"
$LocalDropDirectory = "D:\Installs\"
$RemoteNetworkPath = "\\$ServerFqdn"
$RemoteDropDirectory = "\\$ServerFqdn\Installs"
$ArtifactDirectory = $WorkingDirectory + "\artifacts\"
$UnpackZipDirectory = $ArtifactDirectory + "\Installer\*"
$TokenToolPath = $WorkingDirectory + "\AuthTokenRetrieval\SigningServiceProvisioningPortal.Utility.exe"
$TokenJsonPath = $WorkingDirectory + "\output.json"
$Global:CertificateToken = ""
$ServerPassSs = ConvertTo-SecureString $ServerPass -AsPlainText -Force
$FailedToStartServices = $False
$ReadLogsOnSuccess = 0
$RestoreDbOnFailure = 0
# Set this to 0 to disable db install retry; set to 1+ to configure max retry attempts.
$DbTimeOutRetryMax = 1
$DbTimeOutRetryCount = 0
$DbLogTimeOutSearchString = "*Lock request time out period exceeded*"
$DbLogTimeOutSearchString2016 = "*Execution Timeout Expired*"
$CatName = $DbServer.split("\")[1]

# Provision Nimbus VM for deployment.
function ProvisionNimbus
{
	$NimbusUser =      "svc.aw-nimbus"
	$NimbusPassword =  ConvertTo-SecureString -String "XnW4i339co93FN5kdJF" -AsPlainText -Force
	$NimbusCred =      New-Object -typename System.Management.Automation.PSCredential -argumentlist $NimbusUser, $NimbusPassword
	$Template =        "/templates/Airwatch/AirWatch2k8.ovf"
	$VmName =          "${bamboo.buildResultKey}"
	$ResultFile =      "${bamboo.buildResultKey}.txt"

	New-SSHSession -ComputerName "nimbus-gateway.eng.vmware.com" -Credential ($NimbusCred)
	Write-Host "================================"
	Write-Host "       Deploying Nimbus VM"
	Write-Host "     This will take some time"
	Write-Host "================================"

	Invoke-SSHCommand -Index 0 -Command "nimbus-ovfdeploy -d $VmName $Template --lease=1 --result=$ResultFile" -TimeOut 9999
	$Response = (Invoke-SSHCommand -Index 0 -Command "less /mts/home3/$NimbusUser/$ResultFile").Output | Out-File $ResultFile

	$NimbusInfo =      ((Get-Content '$WorkingDirectory\$ResultFile' -Raw) | ConvertFrom-Json)
	$NimbusIpAddress = $NimbusInfo.ip4
	$NimbusPod =       $NimbusInfo.pod
	$NimbusStatus =    $NimbusInfo.deploy_status
	$NimbusVmName =    $NimbusInfo.name

	if ($NimbusStatus -ne "success")
	{
		Write-Host "================================"
		Write-Host "   Nimbus Deployment Failed"
		Write-Host "================================"
		DeployExit $Session 5
	}

	Write-Host "================================================================"
	Write-Host "  Nimbus Deployment Successful"
	Write-Host "================================================================"
	Write-Host "  Nimbus VM Name is $NimbusVmName"
	Write-Host "  Nimbus VM IP is $NimbusIpAddress"
	Write-Host "  Nimbus Pod is $NimbusPod"
	Write-Host "  Nimbus Kill command is:"
	Write-Host "  NIMBUS=$NimbusPod /mts/git/bin/nimbus-ctl kill $NimbusVmName"
	Write-Host "================================================================"

	#Set $ServerFqdn to $NimbusIpAddress
	$ServerFqdn = $NimbusIpAddress
	$DbServer   = "localhost"
	Invoke-SSHCommand -Index 0 -Command "rm /mts/home3/$NimbusUser/$ResultFile"
	Remove-SSHSession -Index 0
}

# Closes PS Session and exits with value passed.
function DeployExit ($Session, $ExitCode)
{
    Remove-PSSession $Session
	if ($ExitCode -eq 0)
	{
		Write-Host "Success!"
	}
    else
	{
		Write-Error "Ending remote PowerShell session and exiting with $ExitCode. Refer to documentation for information about this exit code."
		if ($FailedToStartServices -eq $True)
		{
			Write-Warning "Some services failed to start. Manually check services and start any that are not running."
		}
	}
	Write-Warning "THIS SCRIPT IS BEING DEPRECATED! YOU NEED TO MOVE YOUR ENVIRONMENT TO DEV 2.0 AND BEING USING BA-DeployAirWatch2 IMMEDIATELY."
	Write-Warning "THIS SCRIPT IS BEING DEPRECATED! YOU NEED TO MOVE YOUR ENVIRONMENT TO DEV 2.0 AND BEING USING BA-DeployAirWatch2 IMMEDIATELY."
	Write-Warning "THIS SCRIPT IS BEING DEPRECATED! YOU NEED TO MOVE YOUR ENVIRONMENT TO DEV 2.0 AND BEING USING BA-DeployAirWatch2 IMMEDIATELY."
	Exit $ExitCode
}

# Try to create a remote PS session.
function CreateSession
{
	try
	{
		Write-Host "Attempting to create remote PowerShell session on $ServerFqdn."
		$Credential = New-Object -typename System.Management.Automation.PSCredential -argumentlist $ServerUser, $ServerPassSs
		$Session = New-PSSession -computername $ServerFqdn -credential $Credential -erroraction Stop
		Write-Host "Successfully connected to $ServerFqdn."
		return $True, $Session
    
	}
	catch
	{
		Write-Host "An error occurred trying to establish a PowerShell remote session with $ServerFqdn."
		Write-Host ""
		Write-Host "Exception: $_"
		return $False
	}
}

# Configuring database name in script.
function GenerateDatabaseBackupScript
{
	Write-Host "Generating database backup script."
	$findValue = 'XXXXXAIRWATCHDBXXXXX'
	(Get-Content $backupScriptPath) | ForEach-Object {$_ -replace $findValue, $DbSchema} | Set-Content $backupScriptPath
}

# Configuring database name in replace script.
function GenerateDatabaseReplaceScript
{
	Write-Host "Generating database restore script."
	$findValue = 'XXXXXAIRWATCHDBXXXXX'
	(Get-Content $copyDatabaseScriptPath) | ForEach-Object {$_ -replace $findValue, $DbSchema} | Set-Content $copyDatabaseScriptPath
	
	$findValue = 'XXXXXDBUSERXXXXX'
	(Get-Content $copyDatabaseScriptPath) | ForEach-Object {$_ -replace $findValue, $DbUser} | Set-Content $copyDatabaseScriptPath
}

# Find and replace environment details based on input arguments.
function UpdateConfigScript
{
	Write-Host "Generating install configuration script."
	
	$findValue = 'XXXXXINSTALLDIRXXXXX'
	(Get-Content $PathToConsoleConfig) | ForEach-Object {$_ -replace $findValue, $InstallDir} | Set-Content $PathToConsoleConfig
	
	$findValue = 'XXXXXDBSERVERXXXXX'
	(Get-Content $PathToConsoleConfig) | ForEach-Object {$_ -replace $findValue, $DbServer} | Set-Content $PathToConsoleConfig
	
	$findValue = 'XXXXXDBNAMEXXXXX'
	(Get-Content $PathToConsoleConfig) | ForEach-Object {$_ -replace $findValue, $DbSchema} | Set-Content $PathToConsoleConfig
	
	$findValue = 'XXXXXDBUSERXXXXX'
	(Get-Content $PathToConsoleConfig) | ForEach-Object {$_ -replace $findValue, $DbUser} | Set-Content $PathToConsoleConfig
	
	$findValue = 'XXXXXDBPASSXXXXX'
	(Get-Content $PathToConsoleConfig) | ForEach-Object {$_ -replace $findValue, $DbPass} | Set-Content $PathToConsoleConfig
	
	$findValue = 'XXXXXCNURLXXXXX'
	(Get-Content $PathToConsoleConfig) | ForEach-Object {$_ -replace $findValue, $CnUrl} | Set-Content $PathToConsoleConfig
	
	$findValue = 'XXXXXDSURLXXXXX'
	(Get-Content $PathToConsoleConfig) | ForEach-Object {$_ -replace $findValue, $DsUrl} | Set-Content $PathToConsoleConfig
	
	$findValue = 'XXXXXCERTTOKENXXXXX'
	(Get-Content $PathToConsoleConfig) | ForEach-Object {$_ -replace $findValue, $CertificateToken} | Set-Content $PathToConsoleConfig
}

# Find and replace database details in RestoreDatabase script.
function GenerateDatabaseRestoreScript
{
	if ($RestoreDbOnFailure -eq 1)
	{
		Write-Host "Generating database restore script."
		
		$findValue = 'XXXXXAIRWATCHDBXXXXX'
		(Get-Content $restoreDbScriptPath) | ForEach-Object {$_ -replace $findValue, $DbSchema} | Set-Content $restoreDbScriptPath
		
		$findValue = 'XXXXXCATXXXXX'
		(Get-Content $restoreDbScriptPath) | ForEach-Object {$_ -replace $findValue, $CatName} | Set-Content $restoreDbScriptPath
		
		$findValue = 'XXXXXDBUSERXXXXX'
		(Get-Content $restoreDbScriptPath) | ForEach-Object {$_ -replace $findValue, $DbUser} | Set-Content $restoreDbScriptPath
	}
}

# Unpacks zip, deletes zip, deletes old artifacts, and copies artifacts to \\ServerFqdn\Installs.
function UnpackAndCopyArtifacts
{
	# Check that artifacts directory exists.
	if ((Test-Path $ArtifactDirectory) -eq $False)
	{
		Write-Host "Could not find an artifacts directory at $ArtifactDirectory. Cannot continue."
		DeployExit $Session 21
	}
	
	# Unpack zip file. Skip if run mode = 5 (db install)
	$zipFileName = Get-ChildItem $ArtifactDirectory | where {$_.extension -eq ".zip" -and $_.name -like "*-App_Installer*"} | % { $_.FullName }
	if ($RunMode -ne 5)
	{
		if ($zipFileName -eq $Null)
		{
			Write-Host "No artifact zip found. Cannot continue."
			DeployExit $Session 21
		}
		Write-Host "Unpacking $zipFileName"
		$Shell = New-Object -com shell.application
		$zipFile = $Shell.NameSpace($zipFileName)
		foreach ($file in $zipFile.items())
		{
			$Shell.NameSpace($ArtifactDirectory).copyhere($file)
		}
	}
	else
	{
		Write-Host "Skipped zip unpack."
	}

	# Moving files from .\Artifacts\Installer\ to .\Artifacts\. Skip if run mode = 5 (db install).
	if ($RunMode -ne 5)
	{
		Move-Item $UnpackZipDirectory $ArtifactDirectory
	}
	
	# Grab config file and DB backup script.
	Write-Host "Getting installer XML and DB scripts."
	Copy-Item $PathToConsoleConfig $ArtifactDirectory -force
	Copy-Item $backupScriptPath $ArtifactDirectory -force
	Copy-Item $resetRoleAndOgPath $ArtifactDirectory -force
	Copy-Item $copyDatabaseScriptPath $ArtifactDirectory -force
	Copy-Item $restoreDbScriptPath $ArtifactDirectory -force

	# Deleting .zip and Installer dir. Skip unpack dir delete if run mode = 5 (db install).
	Write-Host "Cleaning up."
	if ($zipFileName -ne $Null) {Remove-Item -force -recurse -confirm:$false -path $zipFileName}
	if ($RunMode -ne 5)
	{
		Remove-Item -force -recurse $UnpackZipDirectory
	}
	
	# Copy artifacts to D:\Installs\ on remote server.
	Write-Host "Setting remote credentials for $RemoteNetworkPath."
	net use $RemoteNetworkPath $ServerPass /USER:$ServerUser
	Set-Location $ArtifactDirectory
	$Artifacts = Get-ChildItem $ArtifactDirectory
	Write-Host "Cleaning out $RemoteDropDirectory"
	Try
	{
		Remove-Item -force -recurse -confirm:$false ($RemoteDropDirectory + "\*")
	}
	Catch [System.exception]
	{
		Write-Error "Unable to delete files from $RemoteDropDirectory. Cannot continue."
		Write-Host ""
		Write-Host "Exception: $_"
		DeployExit $Session 20
	}
	Write-Host "Copying files."
	Try
	{
		foreach ($Artifact in $Artifacts)
		{
			Copy-Item -force $Artifact $RemoteDropDirectory
		}
	}
	Catch [System.exception]
	{
		Write-Error "Unable to copy build artifacts to $RemoteDropDirectory. Cannot continue."
		Write-Host ""
		Write-Host "Exception: $_"
		DeployExit $Session 20
	}
	Write-Host "Done copying files."
	Write-Host "Deleting remote credentials for $RemoteNetworkPath."
	net use $RemoteNetworkPath /delete
}

# Stop all AirWatch services.
function StopServices ($Session)
{
	Write-Host "Stopping AirWatch services."
	Invoke-Command -session $Session -scriptblock {Stop-Service AirWatch*,GooglePlayS*,w3sv*,LogInsightAgent* -force}
}

# Backup database.
function BackupDatabase ($Session)
{
	Write-Host "Backing up database."
	$ScriptBlock = [scriptblock]::Create("CMD /C sqlcmd -S $DbServer -U $DbUser -P $DbPass -d $DbSchema -b -i `'D:\Installs\BackupDatabase.sql`'")
	Invoke-Command -session $Session -scriptblock $ScriptBlock
	$ExitCode = Invoke-Command -session $Session -scriptblock {$LastExitCode}
	if ($ExitCode -ne 0)
	{
		Write-Error "Database backup failed. Cannot continue."
		if ($RunMode -ne 5)
		{
			Write-Host "Attempting to recover environment."
			StartServices($Session)
		}
		DeployExit $Session 41
	}
	Write-Host "Backup complete."
}

# Reset Administrator user role/OG in AW database.
function ResetAdminUser ($Session)
{
	Write-Host "Resetting role and OG for Administrator user."
	$ScriptBlock = [scriptblock]::Create("CMD /C sqlcmd -S $DbServer -U $DbUser -P $DbPass -d $DbSchema -b -I -i `'D:\Installs\ResetAdminUserRoleAndOG.sql`'")
	Invoke-Command -session $Session -scriptblock $ScriptBlock
	$ExitCode = Invoke-Command -session $Session -scriptblock {$LastExitCode}
	if ($ExitCode -ne 0)
	{
		Write-Error "Failed to reset Administrator Role or OG."
		DeployExit $Session 8
	}
	Write-Host "Role and default OG reset completed successfully."
}

# Restore database from backup.
function RestoreDatabase ($Session)
{
		Write-Host "Restoring database from previously generated backup."
	$ScriptBlock = [scriptblock]::Create("CMD /C sqlcmd -S $DbServer -U $DbSaUser -P $DbSaPass -d $DbSchema -b -I -i `'D:\Installs\RestoreDatabase.sql`'")
	Invoke-Command -session $Session -scriptblock $ScriptBlock
	$ExitCode = Invoke-Command -session $Session -scriptblock {$LastExitCode}
	if ($ExitCode -ne 0)
	{
		Write-Error "Failed to restore database. Cannot continue."
		DeployExit $Session 42
	}
	Write-Host "Database restore successful."
}

# Clear database out.
function RestoreGoldenDbToIntegrationDb ($Session)
{
	Write-Host "Replacing $DbSchema with backup of AirWatch_GoldenDB."
	$ScriptBlock = [scriptblock]::Create("CMD /C sqlcmd -S $DbServer -U $DbSaUser -P $DbSaPass -d $DbSchema -b -I -i `'D:\Installs\ReplaceIntegrationDbWithGoldenDb.sql`'")
	Invoke-Command -session $Session -scriptblock $ScriptBlock
	$ExitCode = Invoke-Command -session $Session -scriptblock {$LastExitCode}
	if ($ExitCode -ne 0)
	{
		Write-Error "Failed to restore database. Cannot continue."
		DeployExit $Session 9
	}
	Write-Host "Database restore successful."
}

# Check if log file contains $DbLogTimeOutSearchString. Returns True/False.
function DidDatabaseTimeout ($PublishLog)
{
	if ($PublishLog -like $DbLogTimeOutSearchString -or $PublishLog -like $DbLogTimeOutSearchString2016)
	{
		return $True
	}
	else
	{
		return $False
	}
}

# Install database.
function InstallDatabase ($Session, $SeedTestData)
{
	Write-Host "Installing DB. This will take awhile."
	$DbInstallerName = Get-ChildItem -filter $DbInstallerSearchString  | % { $_.Name }
	if ($DbInstallerName -eq $Null)
	{
		Write-Host "Could not find DB installer. Cannot continue."
		DeployExit $Session 21
	}
	$DbInstallerPath = $LocalDropDirectory + $DbInstallerName
	if ($SeedTestData -eq 1)
	{
		Write-Warning "This functionality will be removed in near future. Please move away from using integration seed scripts."
		$ScriptBlock = [scriptblock]::Create("CMD /C $DbInstallerPath /s /V`"/qn /lie D:\Installs\DBInstall.log TARGETDIR=$InstallDir INSTALLDIR=$InstallDir AWPUBLISHLOGPATH=D:\Installs\DBPublish.log IS_SQLSERVER_AUTHENTICATION=1 IS_SQLSERVER_SERVER=$DbServer IS_SQLSERVER_USERNAME=$DbUser IS_SQLSERVER_PASSWORD=$DbPass IS_SQLSERVER_DATABASE=$DbSchema AWDEPLOYUNITTESTDATA=IntegrationTests`"")
	}
	else
	{
		$ScriptBlock = [scriptblock]::Create("CMD /C $DbInstallerPath /s /V`"/qn /lie D:\Installs\DBInstall.log TARGETDIR=$InstallDir INSTALLDIR=$InstallDir AWPUBLISHLOGPATH=D:\Installs\DBPublish.log  IS_SQLSERVER_AUTHENTICATION=1 IS_SQLSERVER_SERVER=$DbServer IS_SQLSERVER_USERNAME=$DbUser IS_SQLSERVER_PASSWORD=$DbPass IS_SQLSERVER_DATABASE=$DbSchema`"")
	}
	Invoke-Command -session $Session -scriptblock $ScriptBlock
	$ExitCode = Invoke-Command -session $Session -scriptblock {$LastExitCode}
	
	if ($ExitCode -eq 0 -or $ExitCode -eq 1)
	{
		Write-Host "DB installed successfully."
		if ($ReadLogsOnSuccess -eq 1)
		{
			Write-Host "=============================================================================================="
			Write-Host "======================================DATABASE LOG FILE======================================="
			Invoke-Command -session $Session -scriptblock {Get-Content "D:\Installs\DBInstall.log" | foreach {Write-Output $_}}
			Write-Host "=============================================================================================="
			Write-Host "=============================================================================================="
			$DbInstallSuccessful = $True
		}
	}
	else
	{
		Write-Error "DB install failed."
		Write-Host "Exit code returned from installer: $ExitCode"
		Write-Host "=============================================================================================="
		Write-Host "======================================DATABASE LOG FILE======================================="
		Invoke-Command -session $Session -scriptblock {Get-Content "D:\Installs\DBInstall.log" | foreach {Write-Output $_}}
		Write-Host "=============================================================================================="
		Write-Host "=============================================================================================="
		$DbInstallSuccessful = $False
		$DoesPublishLogExist = Invoke-Command -session $Session -scriptblock {Test-Path "D:\Installs\DBPublish.log"}
		if ($DoesPublishLogExist -eq $True)
		{
			Write-Host "See publish logs below for additional information."
			Write-Host "=============================================================================================="
			Write-Host "=====================================DB PUBLISH LOG FILE======================================"
			$PublishLog = Invoke-Command -session $Session -scriptblock {(Get-Content "D:\Installs\DBPublish.log") | Out-String}
			Invoke-Command -session $Session -scriptblock {Get-Content "D:\Installs\DBPublish.log" | foreach {Write-Output $_}}
			Write-Host "=============================================================================================="
			Write-Host "=============================================================================================="
		}
		else
		{
			Write-Host "No publish logs found. Attempting to recover environment."
			StartServices ($Session)
			DeployExit $Session 40
		}
	}
	
	if ($DbInstallSuccessful -eq $True)
	{
		break
	}
	elseif ($DbInstallSuccessful -eq $False)
	{
		$DbTimeoutRetryCount++
		$DidDatabaseTimeout = DidDatabaseTimeout($PublishLog)
		$PublishLog = Invoke-Command -session $Session -scriptblock {Move-Item "D:\Installs\DBPublish.log" "D:\Installs\DBPublish-$DbTimeOutRetryCount.log"}
		
		# Scenario: DB installation failed, publish logs exist, restore/retry disabled.
		if ($RestoreDbOnFailure -eq 0 -and $DbTimeOutRetryMax -eq 0)
		{
			Write-Host "Restore and retry disabled. Cannot continue."
			DeployExit $Session 40
		}
		# Scenario: DB installation failed, retry enabled but failure isn't time out related.
		if ($DbTimeoutRetryMax -ge 1 -and $RestoreDbOnFailure -eq 0 -and $DidDatabaseTimeout -eq $False)
		{
			Write-Host "Restore disabled and failure not due to time out. Cannot continue."
			DeployExit $Session 40
		}
		# Scenario: DB installation failed, publish logs exist, install timed out, retry attempts not in excess of retry max.
		elseif ($DbTimeOutRetryMax -ge $DbTimeOutRetryCount -and $DidDatabaseTimeout -eq $True)
		{
			Write-Host "Database install timed out. Retrying database installation."
			InstallDatabase ($Session, $SeedTestData)
		}
		# Scenario: DB installation failed, publish logs exist, publish failed.
		elseif ($RestoreDatabase -eq 1 -and $DidDatabaseTimeout -eq $False)
		{
			Write-Host "Database installation failed. Restoring database."
			RestoreDatabase($Session)
			StartServices
			DeployExit $Session 40
		}
		# Scenario: DB installation failed, publish logs exist, retry attempts in excess of retry max.
		elseif ($DbTimeOutRetryMax -le $DbTimeOutRetryCount -and $RestoreDatabase -eq 1)
		{
			Write-Host "Database installation failed. Excessive retry attempts. Restoring database."
			RestoreDatabase($Session)
			StartServices
			DeployExit $Session 40
		}
		# Scenario: Unhandled failure. If this is seen, likely additional scenarios will need to be implemented.
		else
		{
			Write-Host "Database installation failed. Unanticipated failure. Cannot continue."
			DeployExit $Session 40
		}
	}
}

# Install AirWatch.
function InstallAirwatch ($Session)
{
	Write-Host "Installing AirWatch. This will take awhile."
	$AppInstallerName = Get-ChildItem -filter $AppInstallerSearchString  | % { $_.Name }
	if ($AppInstallerName -eq $Null)
	{
		Write-Host "Could not find app installer. Cannot continue."
		DeployExit $Session 21
	}
	$AppInstallerPath = $LocalDropDirectory + $AppInstallerName
	$ScriptBlock = [scriptblock]::Create("CMD /C $AppInstallerPath /s /V`"/qn /lie D:\Installs\AppInstall.log TARGETDIR=$InstallDir INSTALLDIR=$InstallDir AWIGNOREBACKUP=true AWSETUPCONFIGFILE=$ConfigFilePath`"")
	Invoke-Command -session $Session -scriptblock $ScriptBlock
	$ExitCode = Invoke-Command -session $Session -scriptblock {$LastExitCode}
	if ($ExitCode -eq 0 -or $ExitCode -eq 1)
	{
		Write-Host "AirWatch app installed successfully."
		if ($ReadLogsOnSuccess -eq 1)
		{
			Write-Host "=============================================================================================="
			Write-Host "========================================CONSOLE LOG FILE======================================"
			Invoke-Command -session $Session -scriptblock {Get-Content "D:\Installs\AppInstall.log" | foreach {Write-Output $_}}
			Write-Host "=============================================================================================="
			Write-Host "=============================================================================================="
		}
	}
	else
	{
		Write-Error "AirWatch app install failed. Cannot continue."
		Write-Host "Exit code returned from installer: $ExitCode"
		Write-Host "=============================================================================================="
		Write-Host "========================================CONSOLE LOG FILE======================================"
		Invoke-Command -session $Session -scriptblock {Get-Content "D:\Installs\AppInstall.log" | foreach {Write-Output $_}}
		Write-Host "=============================================================================================="
		Write-Host "=============================================================================================="
		DeployExit $Session 50
	}
}

# Start all Airwatch services.
function StartServices ($Session)
{
	Write-Host "Starting AirWatch services."
	try
	{
		Invoke-Command -session $Session -scriptblock {Start-Service AirWatch*,GooglePlayS*,w3sv*,LogInsightAgent*}
	}
	catch
	{
		$FailedToStartServices = $True
		Write-Error "Exception: $_"
	}
}

# Delete old DB details from registry.
function DeleteDatabaseRegistryDetails ($Session)
{
	Write-Host "Deleting old AirWatch database information from registry (if present)."
	Invoke-Command -session $Session -scriptblock {if ((Test-Path -path 'HKLM:\SOFTWARE\Wow6432Node\AirWatch Database') -eq $True) {Remove-Item -path 'HKLM:\SOFTWARE\Wow6432Node\AirWatch Database'}}
	Invoke-Command -session $Session -scriptblock {if ((Test-Path -path 'HKLM:\SOFTWARE\AirWatch Database') -eq $True) {Remove-Item -path 'HKLM:\SOFTWARE\AirWatch Database'}}
}

# Deletes AirWatch cache folder. This is only used for runmode 9. WORKAROUND!!
function DeleteAirWatchCacheFolder ($Session)
{
	Write-Host "Deleting AirWatch cache directory (if present)."
	Invoke-Command -session $Session -scriptblock {if ((Test-Path -path 'E:\AirWatch\Cache') -eq $True) {Remove-Item -force -recurse -confirm:$false -path 'E:\AirWatch\Cache'}}
	Invoke-Command -session $Session -scriptblock {if ((Test-Path -path 'E:\AirWatch\Cache') -eq $True) {Remove-Item -force -recurse -confirm:$false -path 'E:\AirWatch\Cache'}}
}

# Generate certificate signing token, extact from CertTool output, and set global variable
function GetCertSigningToken
{
	Write-Host "Getting certificate signing token."
	& $tokenToolPath
	if ($LastExitCode -eq 0 -and (Test-Path -path $TokenJsonPath))
	{
		$TokenToolOutput = (Get-Content $TokenJsonPath) | ConvertFrom-Json
		Remove-Item -force -recurse -confirm:$false $tokenJsonPath
		$Global:CertificateToken = $TokenToolOutput.token
	}
	else
	{
		Write-Error "Unable to get a signing token. Cannot continue."
		DeployExit $Session 51
	}
}

# Just used for general connectivity testing.
function TestConnectivity ($Session)
{
	Write-Host "Able to connect."
	Write-Host "Test passed!"
	DeployExit $Session 0
	
}

# Installs a single-box environment.
function RegularInstall ($Session)
{
	Write-Host "Performing a single environment `(regular`) install on $ServerFqdn."
	GenerateDatabaseBackupScript
	GenerateDatabaseRestoreScript
	GetCertSigningToken
	UpdateConfigScript
	UnpackAndCopyArtifacts
	StopServices($Session)
	BackupDatabase($Session)
	DeleteDatabaseRegistryDetails($Session)
	InstallDatabase $Session 0
	InstallAirwatch($Session)
	StartServices ($Session)	
}

function RegularInstallForBat ($Session)
{
	Write-Host "Performing a single environment `(regular`) install on $ServerFqdn for BAT suite."
	GenerateDatabaseBackupScript
	GenerateDatabaseRestoreScript
	GetCertSigningToken
	UpdateConfigScript
	UnpackAndCopyArtifacts
	StopServices($Session)
	BackupDatabase($Session)
	DeleteDatabaseRegistryDetails($Session)
	InstallDatabase $Session 0
	ResetAdminUser($Session)
	InstallAirwatch($Session)
	StartServices ($Session)		
}

function RegularInstallForIntTests ($Session)
{
	Write-Host "Performing a single environment `(regular`) install on $ServerFqdn for integration tests."
	Write-Warning "THIS RUN MODE WILL NOT BACK UP $DbSchema ON $DbServer".ToUpper()
	Write-Warning "THIS RUN MODE WILL REPLACE $DbSchema ON $DbServer".ToUpper()
	$TempDbSchema = $DbSchema
	$DbSchema = "AirWatch_GoldenDB"
	GenerateDatabaseBackupScript
	$DbSchema = $TempDbSchema
	GenerateDatabaseReplaceScript
	GetCertSigningToken
	UpdateConfigScript
	UnpackAndCopyArtifacts
	StopServices($Session)
	BackupDatabase($Session)
	RestoreGoldenDbToIntegrationDb($Session)
	ResetAdminUser($Session)
	DeleteAirWatchCacheFolder($Session)
	InstallAirwatch($Session)
	StartServices ($Session)		
}

# Installs database.
function DbInstall ($Session)
{
	Write-Host "Performing a DB install to $DbSchema on $DbServer from $ServerFqdn."
	GenerateDatabaseBackupScript
	GenerateDatabaseRestoreScript
	UnpackAndCopyArtifacts
	StopServices($Session)
	BackupDatabase($Session)
	DeleteDatabaseRegistryDetails($Session)
	# Adding check for integration tests to delete AW cache folder before attempting to run DB installer. WORKAROUND!!
	if ($DbSchema -like "*Golden*")
	{
		DeleteAirWatchCacheFolder($Session)
	}
	InstallDatabase $Session 0
}

# Installs just API services.
function ApiInstall ($Session)
{
	Write-Host "Performing an API-type install on $ServerFqdn."
	GetCertSigningToken
	UpdateConfigScript
	UnpackAndCopyArtifacts
	InstallAirWatch($Session)
	StartServices($Session)
	
}

# Installs just DS services.
function DsInstall ($Session)
{
	Write-Host "Performing a DS-type install on $ServerFqdn."
	GetCertSigningToken
	UpdateConfigScript
	UnpackAndCopyArtifacts
	InstallAirWatch($Session)
	StartServices($Session)
}

# Installs just console services.
function CnInstall ($Session)
{
	Write-Host "Performing a CN-type install on $ServerFqdn."
	GetCertSigningToken
	UpdateConfigScript
	UnpackAndCopyArtifacts
	InstallAirWatch($Session)
	StartServices($Session)
} 

# Deploys a Nimbus VM then does a full Install on the VM.
function NimbusDeploy ($Session)
{
	Write-Host "Performing a single environment `(regular`) install on $ServerFqdn."
	GetCertSigningToken
	UpdateConfigScript
	UnpackAndCopyArtifacts
	InstallDatabase $Session 0
	InstallAirwatch($Session)
	StartServices ($Session)
}

# ==============================================
# This is where the script (really) starts from. 
# ==============================================

# Call ProvisionNimbus if RunMode = 10.
if ($RunMode -eq 10)
{
	ProvisionNimbus
}

while($CreateSessionCount -lt 3)
{
	$CreateSessionCount++
	$CreateSession = CreateSession
	if ($CreateSession -is [array])
	{
		$Session = $CreateSession[1]
		break
	}
	elseif ($CreateSessionCount -ge 3)
	{
		Write-Host "Unable to connect. Cannot continue. Exiting."
		Exit 2
	}
	Start-Sleep -s 5
}

# Sets ConsoleConfigName based on run mode.
if ($RunMode -eq 1 -or $RunMode -eq 8 -or $RunMode -eq 9 -or $RunMode -eq 10)
{
	Write-Host "Generating single-box configuration script for $ServerFqdn."
	$ConsoleConfigName = "Single_ConfigScript.xml"
}
elseif ($RunMode -eq 2)
{
	Write-Host "Generating API-type configuration script for $ServerFqdn."
	$ConsoleConfigName = "API_ConfigScript.xml"	
}
elseif ($RunMode -eq 3)
{
	Write-Host "Generating DS-type configuration script for $ServerFqdn."
	$ConsoleConfigName = "DS_ConfigScript.xml"
}
elseif ($RunMode -eq 4)
{
	
	Write-Host "Generating CN-type configuration script for $ServerFqdn."
	$ConsoleConfigName = "CN_ConfigScript.xml"
}
else
{
	Write-Host "No configuration script required for this run mode."
}

# Set path to app installer config file.
$PathToConsoleConfig = $WorkingDirectory + "\ConfigScripts\" + $ConsoleConfigName
$ConfigFilePath = $LocalDropDirectory + $ConsoleConfigName

# Calls appropriate run mode function.
switch ($RunMode)
{
	0 {TestConnectivity($Session)}
	1 {RegularInstall($Session)}
	2 {ApiInstall($Session)} 
	3 {DsInstall($Session)}
	4 {CnInstall($Session)}
	5 {DbInstall($Session)}
	6 {StopServices($Session)}
	7 {StartServices($Session)}
	8 {RegularInstallForBat($Session)}
	9 {RegularInstallForIntTests($Session)}
	10 {NimbusDeploy($Session)}
	default 
	{
		Write-Host "Unknown run mode: $RunMode. Cannot continue. Exiting."
		DeployExit $Session 3
	}
}

# All went well!
DeployExit $Session 0