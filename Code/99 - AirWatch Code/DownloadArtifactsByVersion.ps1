# File: DownloadArtifactByVersion.ps1
# Uses BITS to download artifacts from Bamboo Samba share.
# PowerShell
# cberndt@vmware.com

Param(
	[Parameter(Mandatory = $true)]
    [string]$BuildNumber
)

if ($BuildNumber.StartsWith("0") -ne $True) 
{
    $BuildNumber = "0" + $BuildNumber
}

Import-Module BitsTransfer

# Determine working directory.
$WorkingDirectory = Split-Path $script:MyInvocation.MyCommand.Path

# Path to file shares on Bamboo.
$AppFileShare = "\\bamboo.air-watch.com\bamboodata\COM-CN\shared\build-$BuildNumber\AirWatch-Build-Artifacts\*.*"
$DbFileShare = "\\bamboo.air-watch.com\bamboodata\COM-CN\shared\build-$BuildNumber\AirWatch-DB-Build-Artifacts\*.*"

# Download destination.
$DownloadDir = $ArtifactDirectory = $WorkingDirectory + "\artifacts\"

# Ensure artifact directory exists.
If ((Test-Path $DownloadDir) -eq "True")
{
    Write-Host "Artifact directory already exists."
    # Remove and recreate Artifact directory.
    Remove-Item ($DownloadDir) -force -verbose -recurse -ErrorAction Stop
    New-Item $DownloadDir -itemtype directory
}
Else
{
    Write-Host "Artifact directory does not exist."
    New-Item $DownloadDir -itemtype directory
    Write-Host "Created directory."
}

Write-Host "Downloading App files from $AppFileShare"
If ((Test-Path $AppFileShare) -eq $false)
{
    Write-Host "Path does not exist. Cannot continue."
    Exit 1
}
Else
{
    Start-BitsTransfer $AppFileShare -Destination $DownloadDir -ErrorAction Stop
}


Write-Host "Downloading DB files from $DbFileShare"
If ((Test-Path $DbFileShare) -eq $false)
{
    Write-Host "Path does not exist. Cannot continue."
    Exit 1
}
Else
{
    Start-BitsTransfer -Source $DbFileShare -Destination $DownloadDir -ErrorAction Stop
}
Write-Host "Done!"
Exit 0