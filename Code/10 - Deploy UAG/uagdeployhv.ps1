#
#  Copyright © 2015, 2016, 2017, 2018 VMware Inc. All rights reserved.
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

<#
    .SYNOPSIS
     Sample Powershell script to deploy a VMware Access Point virtual appliance using ovftool.
    .EXAMPLE
     .\apdeployhyperv.ps1 -iniFile uag1.ini 
#>

param([string]$iniFile = "uag.ini")

#
# Load the dependent PowerShell Module
#

$ScriptPath = $MyInvocation.MyCommand.Path
$ScriptDir  = Split-Path -Parent $ScriptPath
$apDeployModule=$ScriptDir+"\uagdeploy.psm1"

if (!(Test-path $apDeployModule)) {
	WriteErrorString "Error: PowerShell Module $apDeployModule not found."
	Exit
}

import-module $apDeployModule -Force


Write-host "Unified Access Gateway (UAG) virtual appliance deployment script"

$settings = ImportIni $iniFile

if (!(Test-path $iniFile)) {
	WriteErrorString "Error: Configuration file ($iniFile) not found."
	Exit
}

$VMName=$settings.General.name

#
# Assign and validate network settings
#

if ($settings.General.netInternet.length -eq 0) {
	WriteErrorString "Error: Missing netInternet Hyper-V switch name in .ini file"
    Exit
}

$dns=$settings.General.dns
$defaultGateway=$settings.General.defaultGateway
$v6DefaultGateway=$settings.General.v6DefaultGateway

$netInternet=$settings.General.netInternet
$ip0=$settings.General.ip0

$netManagementNetwork=$settings.General.netManagementNetwork
$ip1=$settings.General.ip1

$netBackendNetwork=$settings.General.netBackendNetwork
$ip2=$settings.General.ip2

$gateway0=$settings.General.gateway0
$gateway1=$settings.General.gateway1
$gateway2=$settings.General.gateway2

$netmask0=$settings.General.netmask0
$netmask1=$settings.General.netmask1
$netmask2=$settings.General.netmask2

$routes0=$settings.General.routes0
$routes1=$settings.General.routes1
$routes2=$settings.General.routes2

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

if ($ipAllocationPolicy -eq "fixedPolicy") {
	switch -Wildcard ($deploymentOption) {

		'onenic*' {
			if (!$ip0) {
				WriteErrorString "Error: ip0 in the [General] section of $iniFile is missing."
				Exit
			}

		}
		'twonic*' {
			if (!$ip0) {
				WriteErrorString "Error: ip0 in the [General] section of $iniFile is missing."
				Exit
			}
			if (!$ip1) {
				WriteErrorString "Error: ip1 in the [General] section of $iniFile is missing."
				Exit
			}
            # check for gateway and netmask as well...
		}
		'threenic*' {
			if (!$ip0) {
				WriteErrorString "Error: ip0 in the [General] section of $iniFile is missing."
				Exit
			}
			if (!$ip1) {
				WriteErrorString "Error: ip1 in the [General] section of $iniFile is missing."
				Exit
			}
			if (!$ip2) {
				WriteErrorString "Error: ip2 in the [General] section of $iniFile is missing."
				Exit
			}
		}
		default {
			WriteErrorString "Error: deploymentOption=$deploymentOption in the [General] section of $iniFile is not valid."
			WriteErrorString "It must be set to onenic, twonic or threenic."
			Exit

		}
	}
}

if ($ip0) {
    if (!$gateway0) {
        WriteErrorString "Error: gateway0 in the [General] section of $iniFile is missing."
        Exit
    }

    if (!$netmask0) {
        WriteErrorString "Error: netmask0 in the [General] section of $iniFile is missing."
        Exit
    }
}

if ($ip1) {
    if (!$gateway1) {
        WriteErrorString "Error: gateway1 in the [General] section of $iniFile is missing."
        Exit
    }

    if (!$netmask1) {
        WriteErrorString "Error: netmask1 in the [General] section of $iniFile is missing."
        Exit
    }
}

if ($ip2) {
    if (!$gateway2) {
        WriteErrorString "Error: gateway2 in the [General] section of $iniFile is missing."
        Exit
    }

    if (!$netmask2) {
        WriteErrorString "Error: netmask2 in the [General] section of $iniFile is missing."
        Exit
    }
}

#
# Create New Virtual Machine
#

if ($VMName.length -gt 32) { 
	WriteErrorString "Error: Virtual machine name must be no more than 32 characters in length"
	Exit
}

if (!$VMName) {
	$VMName = VMName
}

$rootPwd = GetRootPwd $VMName
$adminPwd = GetAdminPwd $VMName

$ceipEnabled = GetCeipEnabled $VMName

$settingsJSON=GetJSONSettings $settings

if ($deploymentOption -like "*-large") {
    $vCPU=4
    $vRAM=16GB
    $VHDSize=20GB
} else {
    $vCPU=2
    $vRAM=4GB
    $VHDSize=20GB
}

$progresspreference = "SilentlyContinue"

#
# Stop existing VM of the same name
#

$out=Stop-VM -Name $VMName -TurnOff -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue -ErrorVariable error -WarningVariable warning
if ((!$error) -And (!$warning)) {
    Write-Host "Powered off VM: $VMName"
}

#
# Delete existing VM of the same name
#

$out=Remove-VM -Name $VMName -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue -ErrorVariable error -WarningVariable warning
if ((!$error) -And (!$warning)) {
    Write-Host "Deleted VM: $VMName"
}

$vhdxPath=$settings.General.ds

$out=mkdir $vhdxPath -ErrorAction SilentlyContinue

if (!(Test-path $vhdxPath)) {
	WriteErrorString "Error: unable to create data store folder $vhdxPath - check the datastore (ds) value in $iniFile"
	Exit
}

#
# Copy the initial vhdx image file
#

Write-Host "Copying $VMName starter disk to $vhdxPath"

$vhdxSource=$settings.General.source
$vhdxFile=$vhdxPath
$vhdxFile+="\"
$vhdxFile+=$VMName
$vhdxFile+=".vhdx"

cmd /c copy /z $settings.General.source $vhdxFile

if (!(Test-path $vhdxFile)) {
	WriteErrorString "Error: Failed to copy to $vhdxSource to $vhdxFile"
	Exit
}

#
# Create the new VM
#

Write-Host -NoNewline "Creating new VM: $VMName .."

$out=New-VM -Name $VMName -MemoryStartupBytes $vRAM -VHDPath $vhdxFile -SwitchName $netInternet -ErrorVariable Error -ErrorAction SilentlyContinue
if ($error) {
    Write-Host ". FAILED"
	WriteErrorString "Error: Failed create Access Point $VMName ($Error)"
    Exit
}

Write-Host ". OK"

#
# Add additional NICs if needed
#

if ($netManagementNetwork) {
    Add-VMNetworkAdapter -VMName $VMName -SwitchName $netManagementNetwork -Name "Management Network Adapter" -ErrorVariable Error -ErrorAction SilentlyContinue

    if ($error) {
	    WriteErrorString "Error: Failed to set Management Network NIC $netManagementNetwork - ($Error)"
        Exit
    }
}

if ($netBackendNetwork) {
    Add-VMNetworkAdapter -VMName $VMName -SwitchName $netBackendNetwork -Name "Backend Network Adapter" -ErrorVariable Error -ErrorAction SilentlyContinue
    if ($error) {
	    WriteErrorString "Error: Failed to set Backend Network NIC $netBackendNetwork - ($Error)"
        Exit
    }
}

#
# Start the new VM
#

$out=start-vm -vmname $VMName

# 
# Wait for KVP Exchange Service to start
#

Write-Host -NoNewline "Starting Guest Data Exchange Service ."

$KVPExchangeServiceStatus=Get-VMIntegrationService -VMName $VMName | Where-Object {$_.Name -eq 'Key-Value Pair Exchange'} | Where-Object {$_.PrimaryStatusDescription -eq 'OK'}
 while (! $KVPExchangeServiceStatus) {
    Write-Host -NoNewline "."
    Start-Sleep -Seconds 5 
    $KVPExchangeServiceStatus=Get-VMIntegrationService -VMName $VMName | Where-Object {$_.Name -eq 'Key-Value Pair Exchange'} | Where-Object {$_.PrimaryStatusDescription -eq 'OK'}
 }

Write-Host ". OK"

#
# Poll the VM to wait for it to be up then wait 20 more seconds
#

Write-Host -NoNewline "Waiting for Guest Integration Services to start on $VMName ."

$ipAddress=""
while ($true) {
    Write-Host -NoNewline "."
    if (IsVMUp ($VMName, [ref]$ipAddress)) {
        Start-Sleep 20
        Break
    }
    Start-Sleep -Seconds 5 
}

Write-Host ". OK"

#
# Add Key-Value Pairs for Virtual Machine
#

Write-Host -NoNewline "Setting initial $VMName configuration settings "

$job=AddKVP $VMName "rootPassword" $rootPwd
Write-Host -NoNewline "."

if ($adminPwd.length -gt 0) {
    $job=AddKVP $VMName "adminPassword" $adminPwd
    Write-Host -NoNewline "."
}

if ($ceipEnabled -eq $true) {
	$job=AddKVP $VMName "ceipEnabled" "True"
} else {
	$job=AddKVP $VMName "ceipEnabled" "False"
}

if ($settings.General.tlsPortSharingEnabled -eq "true") {
	$job=AddKVP $VMName "tlsPortSharingEnabled" "True"
}

if ($dns.length -gt 0) {
    $job=AddKVP $VMName "DNS" $dns
    Write-Host -NoNewline "."
}

if ($defaultGateway.length -gt 0) {
    $job=AddKVP $VMName "defaultGateway" $defaultGateway
    Write-Host -NoNewline "."
}

if ($v6DefaultGateway.length -gt 0) {
    $job=AddKVP $VMName "v6DefaultGateway" $v6DefaultGateway
    Write-Host -NoNewline "."
}

switch -Wildcard ($deploymentOption) {

	'onenic*' {
        SetKVPNetOptions $settings $VMName "0"
    }
	'twonic*' {
        SetKVPNetOptions $settings $VMName "0"
        SetKVPNetOptions $settings $VMName "1"
    }
	'threenic*' {
        SetKVPNetOptions $settings $VMName "0"
        SetKVPNetOptions $settings $VMName "1"
        SetKVPNetOptions $settings $VMName "2"
    }
}

if ($routes0) {
    $job=AddKVP $VMName "routes0" $routes0
}

if ($routes1) {
    $job=AddKVP $VMName "routes1" $routes1
}

if ($routes2) {
    $job=AddKVP $VMName "routes2" $routes2
}

$job=AddKVP $VMName "settingsJSON" $settingsJSON

Write-Host ". OK"

if($ipAddress -eq $ip0) {
    # Race Condition !!!
    # IPAddress that the AP got from DHCP is the same as has been configured.
    # Sleep for 3 minutes to give enough time for vmware_ap_sysconfig to be executed
    wait = 0
    while ($wait -le 180) {
        Write-Host -NoNewline "."
        $wait++
        Start-Sleep -Seconds 1
    }
} else {
    $wait = 0
    Write-Host -NoNewline "Applying $VMName configuration settings "
    while(-Not (IsVMDeployed $VMName $ip0 )) {
    Write-Host -NoNewline "."
        if($wait -ge 600) {
            # If its been more than 10 minutes, and VM has still not come up then, deployment failure
            write-Host ". Failed"
            WriteErrorString "UAG virtual appliance $VMName failed to deploy"
            DeleteKVPAll $VMName
            exit
        }
        # Wait utill deployment successful
        $wait++
        Start-Sleep -Seconds 1
    }
}
Write-Host ". OK"

Write-Host -NoNewline "Completing $VMName deployment .."
# Give it 10 seconds for vmware_ap_sysconfig to run
Start-Sleep -Seconds 10
Write-Host ". OK"
DeleteKVPAll $VMName
Write-host "UAG virtual appliance $VMName deployed successfully"
