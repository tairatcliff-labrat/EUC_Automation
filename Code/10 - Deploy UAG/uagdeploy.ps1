#
#  Copyright © 2015, 2016, 2017,2018 VMware Inc. All rights reserved.
#
#  Permission is hereby granted, free of charge, to any person obtaining a copy
#  of the software in this file (the "Software"), to deal in the Software 
#  without restriction, including without limitation the rights to use, copy, 
#  modify, merge, publish, distribute, sublicense, and/or sell copies of the 
#  Software, and to permit persons to whom the Software is furnished to do so, 
#  subject to the following conditions:
#  
#  The above copyright notice and this permission notice shall be included in 
#  all copies or substantial portions of the Software.
#  
#  The names "VMware" and "VMware, Inc." must not be used to endorse or promote 
#  products derived from the Software without the prior written permission of 
#  VMware, Inc.
#  
#  Products derived from the Software may not be called "VMware", nor may 
#  "VMware" appear in their name, without the prior written permission of 
#  VMware, Inc.
#  
#  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL 
#  VMWARE,INC. BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
#  IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
#  CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#
#


<#
    .SYNOPSIS
     Sample Powershell script to deploy a VMware UAG virtual appliance using ovftool.
    .EXAMPLE
     .\apdeploy.ps1 -iniFile uag1.ini 
#>


param([string]$iniFile = "uag.ini", [string] $rootPwd, [string] $adminPwd, [switch] $disableVerification, [switch] $noSSLVerify, [string] $ceipEnabled)

#
# Load the dependent PowerShell Module
#

$ScriptPath = $MyInvocation.MyCommand.Path
$ScriptDir  = Split-Path -Parent $ScriptPath
$apDeployModule=$ScriptDir+"\uagdeploy.psm1"

if (!(Test-path $apDeployModule)) {
	Write-host "Error: PowerShell Module $apDeployModule not found." -foregroundcolor red -backgroundcolor black
	Exit
}

import-module $apDeployModule -Force

Write-host "Unified Access Gateway (UAG) virtual appliance deployment script"

if (!(Test-path $iniFile)) {
	WriteErrorString "Error: Configuration file ($iniFile) not found."
	Exit
}

$settings = ImportIni $iniFile

$apName=$settings.General.name

$logfile="log-$apName.txt"

Remove-item -path $logfile -ErrorAction SilentlyContinue

$ds=$settings.General.ds

if (!$ds) {
	WriteErrorString "Error: ds in the [General] section of $iniFile is missing. Set ds= followed by the data store name."
	Exit
}

$diskMode=$settings.General.diskMode

#
# Assign and validate network settings
#

$dns=$settings.General.dns
$defaultGateway=$settings.General.defaultGateway
$v6DefaultGateway=$settings.General.v6DefaultGateway
$forwardrules=$settings.General.forwardrules
$netInternet=$settings.General.netInternet
$ip0=$settings.General.ip0
$routes0=$settings.General.routes0
$netmask0=$settings.General.netmask0

$netManagementNetwork=$settings.General.netManagementNetwork
$ip1=$settings.General.ip1
$routes1=$settings.General.routes1
$netmask1=$settings.General.netmask1

$netBackendNetwork=$settings.General.netBackendNetwork
$ip2=$settings.General.ip2
$routes2=$settings.General.routes2
$netmask2=$settings.General.netmask2

if ((!$ip0) -And (!$ip1) -And (!$ip2)) {

	#
	# No IP addresses specified so we will use DHCP for address allocation
	#

	$ipAllocationPolicy = "dhcpPolicy"

} else {

	$ipAllocationPolicy = "fixedPolicy"

}

$deploymentOption=$settings.General.deploymentOption

if (!$deploymentOption) {
	$deploymentOption="onenic"
}

$ovftool = "C:\Program Files\VMware\VMware OVF Tool\ovftool.exe"

if (!(Test-path $ovftool)) {
	WriteErrorString "Error: ovftool command not found ($ovftool)"
	Exit
}

$source = $settings.General.source
$target = $settings.General.target
$vmFolder = $settings.General.folder

if (!(Test-path $source)) {
	WriteErrorString "Error: Source Accesss Point image not found ($source)"
	Exit
}

if ($apName.length -gt 32) { 
	WriteErrorString "Error: Virtual machine name must be no more than 32 characters in length"
	Exit
}

if (!$apName) {
	$apName = GetAPName
}

if (!$rootPwd) {
    $rootPwd = GetRootPwd $apName
}

if (!$adminPwd) {
    $adminPwd = GetAdminPwd $apName
}

if (!$ceipEnabled) {
    $ceipEnabled = GetCeipEnabled $apname
}

$settingsJSON=GetJSONSettings $settings

$ovfOptions="--X:enableHiddenProperties --X:waitForIp --X:logFile='$logfile' --X:logLevel=verbose --powerOffTarget --powerOn --overwrite"

#
# idp-metadata settings
#

$idpMetadata = "\'idp-metadata\': {}"

$jsonString = "prop:settingsJSON="
$jsonString += $settingsJSON

$configfile = "${env:APPDATA}\VMware\ovftool.cfg"

#Write-host $jsonString

[IO.File]::WriteAllLines($configfile, $jsonString)

#
# ESX datastore name
#

$ovfOptions += " -ds='$ds'"

$ovfOptions += " --name='"+$apName+"'"
$ovfOptions += " --prop:rootPassword='"+$rootPwd+"'"

if ($adminPwd.length -gt 0) {
	$ovfOptions += " --prop:adminPassword='"+$adminPwd+"'"
}

switch -Wildcard ($deploymentOption) {

	'onenic*' {
        $netOptions0 = GetNetOptions $settings "0"
        $ovfOptions += "$netOptions0"
    }
	'twonic*' {
        $netOptions0 = GetNetOptions $settings "0"
        $ovfOptions += "$netOptions0"
        $netOptions1 = GetNetOptions $settings "1"
        $ovfOptions += "$netOptions1"
    }
	'threenic*' {
        $netOptions0 = GetNetOptions $settings "0"
        $ovfOptions += "$netOptions0"
        $netOptions1 = GetNetOptions $settings "1"
        $ovfOptions += "$netOptions1"
        $netOptions2 = GetNetOptions $settings "2"
        $ovfOptions += "$netOptions2"
    }
}

#$ovfOptions += " --ipAllocationPolicy=$ipAllocationPolicy"
$ovfOptions += " --deploymentOption=$deploymentOption"

if ($dns.length -gt 0) {
	$ovfOptions += " --prop:DNS='$dns'"
}

if ($defaultGateway.length -gt 0) {
	$ovfOptions += " --prop:defaultGateway='$defaultGateway'"
}

if ($v6DefaultGateway.length -gt 0) {
	$ovfOptions += " --prop:v6DefaultGateway='$v6DefaultGateway'"
}

if ($forwardrules.length -gt 0) {
	$ovfOptions += " --prop:forwardrules='$forwardrules'"
}

if ($routes0.length -gt 0) {
	$ovfOptions += " --prop:routes0='"+$routes0+"'"
}

if ($routes1.length -gt 0) {
	$ovfOptions += " --prop:routes1='"+$routes1+"'"
}

if ($routes2.length -gt 0) {
	$ovfOptions += " --prop:routes2='"+$routes2+"'"
}

#
# .ovf definition defaults this to True so on vSphere we only need to set it if False.
#

if ($ceipEnabled -eq $false) {
    $ovfOptions += " --prop:ceipEnabled='False'"
}

if ($settings.General.tlsPortSharingEnabled -eq "true") {
	$ovfOptions += " --prop:tlsPortSharingEnabled='True'"
}

if ($netInternet.length -gt 0) {
	$ovfOptions += " --net:Internet='"+$netInternet+"'"
}

if ($netManagementNetwork.length -gt 0) {
	$ovfOptions += " --net:ManagementNetwork='"+$netManagementNetwork+"'"
}

if ($netBackendNetwork.length -gt 0) {
	$ovfOptions += " --net:BackendNetwork='"+$netBackendNetwork+"'"
}

if ($diskMode.length -gt 0) {
    $ovfOptions += " --diskMode='"+$diskMode+"'"
}

if ($disableVerification) {
    $ovfOptions += " --disableVerification"
}

if ($noSSLVerify) {
    $ovfOptions += " --noSSLVerify"
}

if ($vmFolder.length -gt 0) {
    $ovfOptions += " --vmFolder='"+$vmFolder+"'"
}

$ovfOptions = $ovfOptions -replace "'", '"'
$ovfOptions = $ovfOptions -replace "\\047", "'"
$ovfOptions = "$ovfOptions".Split(" ")
#Write-host $ovfOptions
& $ovftool $ovfOptions $source $target

if ($? -eq "0") {
	if ($ipAllocationPolicy -eq "fixedPolicy") {
		Write-host "Note that the IP addresses will be set to the specified IP addresses for each NIC"
	}
	Write-host "UAG virtual appliance $apName deployed successfully"
} else {
	Write-host "UAG deployment failed. Further information may be found in the log file $logfile"
}

if (Test-path $configfile) {
    Remove-item -path $configfile
}

