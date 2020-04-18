<#
========================================================================
 Created on:   05/25/2018
 Created by:   Tai Ratcliff
 Organization: VMware	 
 Filename:     Install_VMware_EUC.ps1
 Example:      Install_VMware_EUC.ps1 -eucConfigJson eucConfigXML.json
 
 ## Primary script to execute all of the scripts
========================================================================
#>

param(
    [ValidateScript({Test-Path -Path $_})]
    [String]$eucConfigJson = "$PsScriptRoot\eucConfig.json"
)

$eucConfig = Get-Content -Path $eucConfigJson | ConvertFrom-Json

# Import PowerShell modules
Get-Module –ListAvailable VM* | Import-Module
Import-Module "$PsScriptRoot\Tools\VMware.HV.Helper\VMware.HV.Helper.psm1"
Import-Module "$PsScriptRoot\Tools\powernsx-master\module\PowerNSX.psm1"

#PowerCLI 6 is required due to OvfConfiguration commands.
[int]$PowerCliMajorVersion = (Get-PowerCliVersion).major
if ( -not ($PowerCliMajorVersion -ge 6 ) ) { throw "PowerCLI version 6 or above is required" }

$validate = (Read-Host "Would you like to validate the JSON settings?: [y/n]").ToLower()
If($validate -eq "y"){
    & '.\Code\00 - Validate Environment\eucDeploymentValidate.ps1'
}
$deployNSX = (Read-Host "Would you like to deploy NSX networking?: [y/n]").ToLower()
If($deployNSX -eq "y"){
    & '.\Code\01 - nsxDeployNetworking\nsxDeployNetwork.ps1'
}
$cloneHorizonVMs = (Read-Host "Would you like to clone the Horizon VMs?: [y/n]").ToLower()
If($cloneHorizonVMs -eq "y"){
    & '.\Code\02 - cloneHorizonVMs\cloneHorizonVMs-1.0.0.ps1'
}
$installConnectionsServers = (Read-Host "Would you like to install the Connection Servers?: [y/n]").ToLower()
If($installConnectionsServers -eq "y"){
    & '.\Code\03 - installConnectionServers\installConnectionServers.ps1'
}
$buildNSXDesktopNetworks = (Read-Host "Would you like to build the NSX Desktop Networks?: [y/n]").ToLower()
If($buildNSXDesktopNetworks -eq "y"){
    & '.\Code\04 - buildNSXDesktopNetworks\buildNSXDesktopNetworks.ps1'
}
$buildDesktopPools = (Read-Host "Would you like to deploy the Desktop Pools?: [y/n]").ToLower()
If($buildDesktopPools -eq "y"){
    & '.\Code\05 - buildDesktopPools\buildDesktopPools.ps1'
}
