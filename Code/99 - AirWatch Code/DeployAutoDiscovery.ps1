# File: DeployAutoDiscovery.ps1
# Installs AirWatch using the headless installer.
# PowerShell 4
# Chas Berndt

# Suppress errors. Leave the below line commented out for now.
#$ErrorActionPreference = "SilentlyContinue"

Write-Host "===================="
Write-Host "Deploy AutoDiscovery"
Write-Host "===================="

# Checking for PowerShell 4+
if ($PsVersionTable.PSVersion.Major -lt 4)
{
	Write-Host "This script requires a MINIMUM of PowerShell 4. Cannot continue."
	Exit 1
}

# Check arg count.
if ($Args.count -ne 8 -and $Args[0] -ne 0)
{
	Write-Host "You must provide eight arguments: RunMode, ServerFqdn, ServerUrl, DBServer, DBName, DBUser, PortalAuthUrl, and PortalAuthKey. See documentation for more details."
	Exit 4
}

# Determine working directory.
$WorkingDirectory = Split-Path $script:MyInvocation.MyCommand.Path

# Required values.
[int]$RunMode = $Args[0]
$ServerFqdn = $Args[1]
$ServerUrl = $Args[2]
$DbServer = $Args[3]
$DbSchema = $Args[4]
$DbUser = $Args[5]
$EnvType = "DEV"
$PortalAuthUrl = $Args[6]
$PortalAuthKey = $Args[7]

$ServerUser = "awsso\svcautodeploy"
$ServerPass = "Ucantcm3!"
$InstallDir = "E:\AutoDiscovery\"
$DbPass = "A1rWatchAdm1n"
$ADInstallerSearchString = "AirWatch_Auto_Discovery_*"
$backupScriptPath = $WorkingDirectory + "\BackupDatabase.sql"
$dropScriptPath = $WorkingDirectory + "\DropDatabase.sql"
$LocalDropDirectory = "D:\Installs\"
$RemoteNetworkPath = "\\$ServerFqdn"
$RemoteDropDirectory = "\\$ServerFqdn\Installs"
$ArtifactDirectory = $WorkingDirectory + "\artifacts\"
$ServerPassSs = ConvertTo-SecureString $ServerPass -AsPlainText -Force
$ReadLogsOnSuccess = 0

# Closes PS Session and exits with value passed.
function DeployExit ($Session, $ExitCode)
{
    Remove-PSSession $Session
    Write-Host "Ending remote PowerShell session and exiting with $ExitCode."
    Write-Warning "THIS SCRIPT IS BEING DEPRECATED! YOU NEED TO MOVE YOUR ENVIRONMENT TO DEV 2.0 AND BEING USING BA-DeployAutoDiscovery IMMEDIATELY."
	Write-Warning "THIS SCRIPT IS BEING DEPRECATED! YOU NEED TO MOVE YOUR ENVIRONMENT TO DEV 2.0 AND BEING USING BA-DeployAutoDiscovery IMMEDIATELY."
	Write-Warning "THIS SCRIPT IS BEING DEPRECATED! YOU NEED TO MOVE YOUR ENVIRONMENT TO DEV 2.0 AND BEING USING BA-DeployAutoDiscovery IMMEDIATELY."
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

# Configuring database name in script.
function GenerateDatabaseDropScript
{
	Write-Host "Generating database delete script."
	$findValue = 'XXXXXAIRWATCHDBXXXXX'
	(Get-Content $dropScriptPath) | ForEach-Object {$_ -replace $findValue, $DbSchema} | Set-Content $dropScriptPath
}

# Unpacks zip, deletes zip, deletes old artifacts, and copies artifacts to \\ServerFqdn\Installs.
function UnpackAndCopyArtifacts
{
	# Grab DB backup script.
	Copy-Item $backupScriptPath $ArtifactDirectory -force
	Copy-Item $dropScriptPath $ArtifactDirectory -force

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
		Write-Host "Unable to delete files from $RemoteDropDirectory. Cannot continue."
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
		Write-Host "Unable to copy build artifacts to $RemoteDropDirectory. Cannot continue."
		Write-Host ""
		Write-Host "$_.Exception.Message"
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
	Invoke-Command -session $Session -scriptblock {Stop-Service AirWatch*,w3sv*,LogInsightAgent*}
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
		Write-Host "Database backup failed. Cannot continue."
		DeployExit $Session 41
	}
	Write-Host "Backup complete."
}

# Drop database. NOTE: User MUST have access to msdb and dbowner rights else this will fail.
function DropDatabase ($Session)
{
	Write-Host "Deleting database."
	$ScriptBlock = [scriptblock]::Create("CMD /C sqlcmd -S $DbServer -U $DbUser -P $DbPass -d master -b -i `'D:\Installs\DropDatabase.sql`'")
	Invoke-Command -session $Session -scriptblock $ScriptBlock
	$ExitCode = Invoke-Command -session $Session -scriptblock {$LastExitCode}
	if ($ExitCode -ne 0)
	{
		Write-Host "Database delete failed. Cannot continue."
		DeployExit $Session 9
	}
	Write-Host "Database delete complete."
}

# Install AutoDiscovery.
function InstallAutoDiscovery ($Session, $SeedTestData)
{
	Write-Host "Installing AutoDiscovery. This will take awhile."
	$ADInstallerName = Get-ChildItem -filter $ADInstallerSearchString  | % { $_.Name }
	$AppInstallerPath = $LocalDropDirectory + $ADInstallerName
	if ($SeedTestData -eq 1)
	{
		$ScriptBlock = [scriptblock]::Create("CMD /C $AppInstallerPath /s /V`"/qn /lie D:\Installs\ADInstall.log TARGETDIR=$InstallDir INSTALLDIR=$InstallDir IS_SQLSERVER_AUTHENTICATION=1 IS_SQLSERVER_SERVER=$DbServer IS_SQLSERVER_USERNAME=$DbUser IS_SQLSERVER_PASSWORD=$DbPass IS_SQLSERVER_DATABASE=$DbSchema AWEXTERNALURL=$ServerUrl AWPORTALAUTHURL=$PortalAuthUrl AWPORTALAUTHKEY=$PortalAuthKey AWENVIRONMENTTYPE=$EnvType AWDEPLOYINTEGRATIONTESTS=true`"")
	}
	else
	{
		$ScriptBlock = [scriptblock]::Create("CMD /C $AppInstallerPath /s /V`"/qn /lie D:\Installs\ADInstall.log TARGETDIR=$InstallDir INSTALLDIR=$InstallDir IS_SQLSERVER_AUTHENTICATION=1 IS_SQLSERVER_SERVER=$DbServer IS_SQLSERVER_USERNAME=$DbUser IS_SQLSERVER_PASSWORD=$DbPass IS_SQLSERVER_DATABASE=$DbSchema AWEXTERNALURL=$ServerUrl AWPORTALAUTHURL=$PortalAuthUrl AWPORTALAUTHKEY=$PortalAuthKey AWENVIRONMENTTYPE=$EnvType`"")
	}
	Invoke-Command -session $Session -scriptblock $ScriptBlock
	$ExitCode = Invoke-Command -session $Session -scriptblock {$LastExitCode}
	if ($ExitCode -eq 0 -or $ExitCode -eq 1)
	{
		Write-Host "AutoDiscovery installed successfully."
		if ($ReadLogsOnSuccess -eq 1)
		{
			Write-Host "===================================================================================================="
			Write-Host "====================================AUTODISCOVERY LOG FILE=========================================="
			Invoke-Command -session $Session -scriptblock {Get-Content "D:\Installs\ADInstall.log" | foreach {Write-Output $_}}
			Write-Host "===================================================================================================="
			Write-Host "===================================================================================================="
		}
	}
	else
	{
		Write-Host "AutoDiscovery install failed. Cannot continue."
		Write-Host "Exit code returned from installer: $ExitCode"
		Write-Host "===================================================================================================="
		Write-Host "====================================AUTODISCOVERY LOG FILE=========================================="
		Invoke-Command -session $Session -scriptblock {Get-Content "D:\Installs\ADInstall.log" | foreach {Write-Output $_}}
		Write-Host "===================================================================================================="
		Write-Host "===================================================================================================="
		DeployExit $Session 60
	}
}

# Start all Airwatch services.
function StartServices ($Session)
{
	Write-Host "Starting AirWatch services."
	Invoke-Command -session $Session -scriptblock {Start-Service AirWatch*,w3sv*,LogInsightAgent*}
}

# Just used for general connectivity testing.
function TestConnectivity ($Session)
{
	Write-Host "Able to connect."
	Write-Host "Test passed!"
	DeployExit $Session 0
	
}

# Installs AutoDiscovery.
function AutoDiscoveryInstall ($Session)
{
	Write-Host "Installing AutoDiscovery on $ServerFqdn."
	GenerateDatabaseBackupScript
	UnpackAndCopyArtifacts
	StopServices($Session)
	BackupDatabase($Session)
	InstallAutoDiscovery $Session 0
	StartServices($Session)
}

# Installs AutoDiscovery and run integration seed scripts.
function AutoDiscoveryInstallForIntTests ($Session)
{
	Write-Host "Installing AutoDiscovery on $ServerFqdn."
	Write-Host "This run mode will trigger insertion of seed test data for running integration tests."
	Write-Warning "This run mode will NOT backup the database $DbSchema on $DBServer".ToUpper()
	GenerateDatabaseDropScript
	UnpackAndCopyArtifacts
	StopServices($Session)
	DropDatabase($Session)
	InstallAutoDiscovery $Session 1
	StartServices($Session)
}

# ==============================================
# This is where the script (really) starts from. 
# ==============================================

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

# Calls appropriate run mode function.
switch ($RunMode)
{
	0 {TestConnectivity($Session)}
	1 {AutoDiscoveryInstall($Session)}
	2 {AutoDiscoveryInstallForIntTests($Session)}
	default 
	{
		Write-Host "Unknown run mode: $RunMode. Cannot continue. Exiting."
		DeployExit $Session 3
	}
}

# All went well!
DeployExit $Session 0