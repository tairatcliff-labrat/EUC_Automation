# File: BA-DeployENSV2.ps1
# Installs AirWatch using the headless installer.
# PowerShell 4
# Seshasaina Vengalam

# Suppress errors. Leave the below line commented out for now.
#$ErrorActionPreference = "SilentlyContinue"

Write-Host "===================="
Write-Host "Deploy ENS"
Write-Host "===================="

# Checking for PowerShell 4+
if ($PsVersionTable.PSVersion.Major -lt 4)
{
	Write-Host "This script requires a MINIMUM of PowerShell 4. Cannot continue."
	Exit 1
}

# Check arg count.
if ($Args.count -ne 6 -and $Args[0] -ne 0)
{
	Write-Host "You must provide Six arguments: RunMode, ServerFqdn, DBServer, DBName, DBUser and CertificatePassword. See documentation for more details."
	Exit 4
}

# Determine working directory.
$WorkingDirectory = Split-Path $script:MyInvocation.MyCommand.Path

# Required values.
[int]$RunMode = $Args[0]
$ServerFqdn = $Args[1]
$DbServer = $Args[2]
$DbSchema = $Args[3]
$DbUser = $Args[4]
$EnvType = "DEV"
$CertificatePassword = $Args[5]

$ServerUser = "svcautodeploy"
$ServerPass = "Ucantcm3!"
$InstallDir = "C:\AirWatch\"
$DbPass = "password"
$ENSV2InstallerSearchString = "AirWatch_ENS_*"
$backupScriptPath = $WorkingDirectory + "\BackupDatabase.sql"
$dropScriptPath = $WorkingDirectory + "\DropDatabase.sql"
$LocalDropDirectory = "C:\Installers\"
$RemoteNetworkPath = "\\$ServerFqdn"
$RemoteDropDirectory = "\\$ServerFqdn\Installs"
$ArtifactDirectory = $WorkingDirectory + "\artifacts\"
$ServerPassSs = ConvertTo-SecureString $ServerPass -AsPlainText -Force
$ReadLogsOnSuccess = 0

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
	Exit $ExitCode
}

# Try to create a remote PS session.
function CreateSession
{
	try
	{
		Write-Host "Attempting to create remote PowerShell session on $ServerFqdn."
		$Credential = New-Object -typename System.Management.Automation.PSCredential -argumentlist $ServerUser, $ServerPassSs
		$Session = New-PSSession -computername $ServerFqdn -credential $Credential -authentication Basic -erroraction Stop
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

# Unpacks zip, deletes zip, deletes old artifacts, and copies artifacts to \\ServerFqdn\Installs.
function UnpackAndCopyArtifacts
{
	# Grab DB backup script.
	Copy-Item $backupScriptPath $ArtifactDirectory -force
	Copy-Item $dropScriptPath $ArtifactDirectory -force

	# Copy artifacts to C:\Installers\ on remote server.
	Write-Host "Setting remote credentials for $RemoteNetworkPath."
	net use $RemoteNetworkPath $ServerPass /USER:domain\$ServerUser
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
	Invoke-Command -session $Session -scriptblock {Stop-Service AirWatch*,w3sv*}
}

# Install ENS.
function InstallENS ($Session, $SeedTestData)
{
	Write-Host "Installing ENS. This will take awhile."
	$ENSV2InstallerName = Get-ChildItem -filter $ENSV2InstallerSearchString  | % { $_.Name }
	$AppInstallerPath = $LocalDropDirectory + $ENSV2InstallerName

	$ScriptBlock = [scriptblock]::Create("CMD /C $AppInstallerPath /s /V`"/qn /lie C:\Installs\ENSV2Install.log IS_SQLSERVER_AUTHENTICATION=1 IS_SQLSERVER_SERVER=$DbServer IS_SQLSERVER_USERNAME=$DbUser IS_SQLSERVER_PASSWORD=$DbPass IS_SQLSERVER_DATABASE=$DbSchema AWCONFIGPATH=C:\ENSV2Config\config.xml AWUSERPROVIDEDPASS=$CertificatePassword AWENVIRONMENTTYPE=$EnvType`"")

	Invoke-Command -session $Session -scriptblock $ScriptBlock
	$ExitCode = Invoke-Command -session $Session -scriptblock {$LastExitCode}
	if ($ExitCode -eq 0 -or $ExitCode -eq 1)
	{
		Write-Host "ENS installed successfully."
		if ($ReadLogsOnSuccess -eq 1)
		{
			Write-Host "===================================================================================================="
			Write-Host "====================================ENS LOG FILE=========================================="
			Invoke-Command -session $Session -scriptblock {Get-Content "C:\Installs\ENSV2Install.log" | foreach {Write-Output $_}}
			Write-Host "===================================================================================================="
			Write-Host "===================================================================================================="
		}
	}
	else
	{
		Write-Host "ENS install failed. Cannot continue."
		Write-Host "Exit code returned from installer: $ExitCode"
		Write-Host "===================================================================================================="
		Write-Host "====================================ENS LOG FILE=========================================="
		Invoke-Command -session $Session -scriptblock {Get-Content "C:\Installs\ENSV2Install.log" | foreach {Write-Output $_}}
		Write-Host "===================================================================================================="
		Write-Host "===================================================================================================="
		DeployExit $Session 60
	}
}

# Start all Airwatch services.
function StartServices ($Session)
{
	Write-Host "Starting AirWatch services."
	Invoke-Command -session $Session -scriptblock {Start-Service AirWatch*,w3sv*}
}

# Just used for general connectivity testing.
function TestConnectivity ($Session)
{
	Write-Host "Able to connect."
	Write-Host "Test passed!"
	DeployExit $Session 0
	
}

# Installs ENS.
function ENSInstall ($Session)
{
	Write-Host "Installing ENS on $ServerFqdn."
	
	UnpackAndCopyArtifacts
	StopServices($Session)
	InstallENS $Session 0
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
	1 {ENSInstall($Session)}
	default 
	{
		Write-Host "Unknown run mode: $RunMode. Cannot continue. Exiting."
		DeployExit $Session 3
	}
}


# All went well!
DeployExit $Session 0