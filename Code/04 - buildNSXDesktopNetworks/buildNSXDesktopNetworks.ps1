<#
========================================================================
 Created on:   05/25/2018
 Created by:   Tai Ratcliff
 Organization: VMware	 
 Filename:     buildNsxDesktopNetworks.ps1
 Example:      buildNsxDesktopNetworks.ps1 -eucConfigJson eucConfigXML.json
========================================================================
#>

param(
    [ValidateScript({Test-Path -Path $_})]
    [String]$eucConfigJson = "$PsScriptRoot\..\..\eucConfig.json"
)

$eucConfig = Get-Content -Path $eucConfigJson | ConvertFrom-Json

#Clear-Host  

#############################################
#############################################
# NSX Infrastructure Configuration.  Adjust to suit environment.

$DesktopNsxManagerServer = If($eucConfig.nsxConfig.desktopNsxManagerServer){$eucConfig.nsxConfig.desktopNsxManagerServer} Else {throw "Desktop NSX Manager is not set"}
$DesktopNsxAdminPassword = If($eucConfig.nsxConfig.desktopNsxAdminPassword){$eucConfig.nsxConfig.desktopNsxAdminPassword} Else {throw "Desktop NSX Manager password is not set"}
$DesktopvCenterUserName = If($eucConfig.nsxConfig.desktopvCenterUserName){$eucConfig.nsxConfig.desktopvCenterUserName} Else {throw "Desktop vCenter username is not set"}
$DesktopvCenterPassword = If($eucConfig.nsxConfig.desktopvCenterPassword){$eucConfig.nsxConfig.desktopvCenterPassword} Else {throw "Desktop vCenter password is not set"}

############################################
############################################
# Topology Details.  No need to modify below here

#Names
$DesktopLsName = If($eucConfig.nsxConfig.desktopLsName){$eucConfig.nsxConfig.desktopLsName} Else {throw "Desktop logical switch name is not set"}
$RDSLsName = If($eucConfig.nsxConfig.RdsLsName){$eucConfig.nsxConfig.RdsLsName} Else {throw "RDS logical switch name is not set"}
$DesktopLdrName = If($eucConfig.nsxConfig.desktopLdrName){$eucConfig.nsxConfig.desktopLdrName} Else {throw "Desktop logical router name is not set"}
$DesktopTransportZoneName = If($eucConfig.nsxConfig.desktopTransportZoneName){$eucConfig.nsxConfig.desktopTransportZoneName} Else {throw "Desktop transport zone name is not set"}

# Configuration
$dnsServer = If($eucConfig.horizonConfig.connectionServers.dnsServerIP){$eucConfig.horizonConfig.connectionServers.dnsServerIP} Else {throw "DNS server not set"}
$DesktopNetwork = If($eucConfig.nsxConfig.desktopNetwork){$eucConfig.nsxConfig.desktopNetwork} Else {throw "Desktop network is not set"}
$DesktopNetworkPrimaryAddress = If($eucConfig.nsxConfig.desktopNetworkPrimaryAddress){$eucConfig.nsxConfig.desktopNetworkPrimaryAddress} Else {throw "Desktop network primary address is not set"}
$desktopSubnetMask = If($eucConfig.nsxConfig.desktopSubnetMask){$eucConfig.nsxConfig.desktopSubnetMask} Else {throw "Desktop subnet mask name is not set"}
$RdsNetwork = If($eucConfig.nsxConfig.desktopRdsNetwork){$eucConfig.nsxConfig.desktopRdsNetwork} Else {throw "RDS network is not set"}
$RdsNetworkPrimaryAddress = If($eucConfig.nsxConfig.desktopRdsNetworkPrimaryAddress){$eucConfig.nsxConfig.desktopRdsNetworkPrimaryAddress} Else {throw "RDS network primary address is not set"}
$RdsSubnetMask = If($eucConfig.nsxConfig.desktopRdsSubnetMask){$eucConfig.nsxConfig.desktopRdsSubnetMask} Else {throw "RDS subnet mask is not set"}
$desktopEdge01Name = If($eucConfig.nsxConfig.desktopEdge01Name){$eucConfig.nsxConfig.desktopEdge01Name} Else {throw "Desktop edge name is not set"}
$desktopEdge01TransitIP = If($eucConfig.nsxConfig.desktopEdge01TransitIP){$eucConfig.nsxConfig.desktopEdge01TransitIP} Else {throw "Desktop edge transip IP is not set"}

$useEdgeDHCPServer = If($eucConfig.nsxConfig.useEdgeDHCPServer){$eucConfig.nsxConfig.useEdgeDHCPServer} Else {throw "To configure the edge to use DHCP it needs to be set to either 'true' of 'false'"}
    [System.Convert]::ToBoolean($useEdgeDHCPServer) | Out-Null    

If($useEdgeDHCPServer ){
    $dhcpServerAddress = If($eucConfig.nsxConfig.desktopDhcpServerAddress){$eucConfig.nsxConfig.desktopDhcpServerAddress} Else {Write-Host -foreground Red "DHCP server is not set"}
}

$deployMicroSeg = If($eucConfig.nsxConfig.deployMicroSeg){$eucConfig.nsxConfig.deployMicroSeg} Else {throw "Deploy micro seg needs to be set to either 'true' of 'false'"}
    [System.Convert]::ToBoolean($deployMicroSeg) | Out-Null    
If($deployMicroSeg){
    ## Security Groups
    $desktopSgName = If($eucConfig.nsxConfig.desktopSgName){$eucConfig.nsxConfig.desktopSgName} Else {throw "Desktop security group is not set"}
    $desktopSgDescription = If($eucConfig.nsxConfig.desktopSgDescription){$eucConfig.nsxConfig.desktopSgDescription} Else {throw "Desktop security group description is not set"}
    ## Security Tags
    $desktopStName = If($eucConfig.nsxConfig.desktopStName){$eucConfig.nsxConfig.desktopStName} Else {throw "Desktop security tag is not set"}
    ##DFW
    $desktopFirewallSectionName = If($eucConfig.nsxConfig.desktopFirewallSectionName){$eucConfig.nsxConfig.desktopFirewallSectionName} Else {throw "Desktop firewall section name is not set"}
}

######################################
# Functions

function IP-toINT64 () {
    param (
        [Parameter (Mandatory=$true, Position=1)]
        [string]$ip
    )
    $octets = $ip.split(".")
    return [int64]([int64]$octets[0]*16777216 +[int64]$octets[1]*65536 +[int64]$octets[2]*256 +[int64]$octets[3])
}

function INT64-toIP() {
    param ([int64]$int)

    return (([math]::truncate($int/16777216)).tostring()+"."+([math]::truncate(($int%16777216)/65536)).tostring()+"."+([math]::truncate(($int%65536)/256)).tostring()+"."+([math]::truncate($int%256)).tostring() )
}



###############################
# Validation
# Connect to vCenter
# Check for PG, DS, Cluster

#Get Connection required.
try {
    Connect-NsxServer -server $DesktopNsxManagerServer -Username 'admin' -password $DesktopNsxAdminPassword -VIUsername $DesktopvCenterUserName -VIPassword $DesktopvCenterPassword -ViWarningAction Ignore -DebugLogging | out-null 
} catch {
    Throw "Failed connecting.  Check connection details and try again.  $_"
}

######################################
######################################
## Topology Deployment

write-host -foregroundcolor Green "NSX Horizon Desktop deployment beginning.`n"
######################################
#Logical Switches

write-host -foregroundcolor "Green" "Creating Logical Switches `n"

## Creates logical switches
$DesktopLs = Get-NsxTransportZone $DesktopTransportZoneName | New-NsxLogicalSwitch $DesktopLsName
$RdsLs = Get-NsxTransportZone $DesktopTransportZoneName | New-NsxLogicalSwitch $RdsLsName

Write-Host $DesktopLs -ForegroundColor Red

# DLR Appliance has the uplink router interface created first.
write-host -foregroundcolor "Green" "Connecting Logical Switches to DLR `n"
Get-NsxLogicalRouter $DesktopLdrName | New-NsxLogicalRouterInterface -type Uplink -Name $DesktopLsName -ConnectedTo $DesktopLs -PrimaryAddress $DesktopNetworkPrimaryAddress -SubnetPrefixLength $DesktopSubnetBits | Out-Null
Get-NsxLogicalRouter $DesktopLdrName | New-NsxLogicalRouterInterface -type Uplink -Name $RdsLsName -ConnectedTo $RdsLs -PrimaryAddress $RdsNetworkPrimaryAddress -SubnetPrefixLength $RdsSubnetBits | Out-Null


####################################################################################################
# Enable DHCP Relay on Desktop Network - This is not available via PowerNSX and requires API calls.

Write-Host "Starting DHCP configuration `n" -ForegroundColor Green
$DesktopLdr = Get-NsxLogicalRouter $DesktopLdrName
If($useEdgeDHCPServer){
    $dhcpServerAddress = $desktopEdge01TransitIP
}
$dhcpModified = $False

$uriDhcpRelayConfig = "/api/4.0/edges/$($DesktopLdr.id)/dhcp/config/relay"
$dhcpRelayResponse = Invoke-NsxRestMethod -method GET -URI $uriDhcpRelayConfig

$xmlDhcpRelayRoot = $dhcpRelayResponse.SelectSingleNode("//relay")
$xmlRelayServerRoot = $dhcpRelayResponse.SelectSingleNode("//relay/relayServer")

if (-not ($xmlRelayServerRoot) ) {
    Add-XmlElement -xmlRoot $xmlDhcpRelayRoot -xmlElementName "relayServer"
    $xmlRelayServerRoot = $dhcpRelayResponse.SelectSingleNode("//relay/relayServer")
}

if (-not $dhcpRelayResponse.SelectSingleNode("//relay/relayServer[ipAddress='$($dhcpServerAddress)']")) {
    Add-XmlElement -xmlRoot $xmlRelayServerRoot -xmlElementName "ipAddress" -xmlElementText $dhcpServerAddress
    $dhcpModified = $True         
}

$xmlDhcpRelayAgentsRoot = $dhcpRelayResponse.SelectSingleNode("//relay/relayAgents")
if (-not ($xmlDhcpRelayAgentsRoot) ) {
    Add-XmlElement -xmlRoot $xmlDhcpRelayRoot -xmlElementName "relayAgents"
    $xmlDhcpRelayAgentsRoot = $dhcpRelayResponse.SelectSingleNode("//relay/relayAgents")
}

write-host "Adding DHCP Relay Agents if required" -ForegroundColor Green
foreach ($interface in (Get-NsxLogicalRouter $DesktopLdrName | Get-NsxLogicalRouterInterface | Where-Object {($_.name -eq "$DesktopLsName") -or ($_.name -eq "$RdsLsName")})) {
    if (-not ($dhcpRelayResponse.SelectSingleNode("//relay/relayAgents/relayAgent[vnicIndex='$($interface.index)']")) ) {
        [System.XML.XMLDocument]$xmlDoc = New-Object System.XML.XMLDocument
        [System.XML.XMLElement]$xmlRelayAgent = $XMLDoc.CreateElement("relayAgent")
        $xmlDoc.appendChild($xmlRelayAgent) | out-null
        Add-XmlElement -xmlRoot $xmlRelayAgent -xmlElementName "vnicIndex" -xmlElementText $interface.index
        $importedRelayAgent = $dhcpRelayResponse.ImportNode($xmlRelayAgent, $True)
        $xmlDhcpRelayAgentsRoot = $dhcpRelayResponse.SelectSingleNode("//relay/relayAgents")
        $xmlDhcpRelayAgentsRoot.appendChild($importedRelayAgent) | out-null
        $dhcpModified = $True     
    }
}

if ($dhcpModified -eq $True) {
    write-host "Updating DHCP Relay configuration" -ForegroundColor Green
    Invoke-NsxRestMethod -method PUT -URI $uriDhcpRelayConfig -body $dhcpRelayResponse.OuterXml    
}


####################################################################################################
# Enable DHCP server on ESG
if($useEdgeDHCPServer){
    $desktopEdge = Get-NsxEdge | Where-Object {$_.Name -eq $desktopEdge01Name}

    $edgeDhcpModified = $False

    $uriEdgeDhcpConfig = "/api/4.0/edges/$($desktopEdge.id)/dhcp/config"
    $edgeDhcpConfig = Invoke-NsxRestMethod -method GET -URI $uriEdgeDhcpConfig

    if ($edgeDhcpConfig.dhcp.enabled -eq 'false') {
        write-host "Configuring DHCP Server on ESG $($desktopEdge.name) ($($desktopEdge.id))"
        $edgeDhcpConfig.dhcp.enabled = "true"
        $edgeDhcpModified = $True    
    }

    $xmlEdgeDhcpPoolRoot = $edgeDhcpConfig.SelectSingleNode("//dhcp/ipPools")

    # Configure Desktop DHCP Settings
    $desktopNetworkDetails = Get-NetworkRange -Network $DesktopNetwork -SubnetMask $DesktopSubnetMask
    $desktopStartAddress = INT64-toIP((IP-toINT64($DesktopNetwork)) + 3)
    $desktopEndAddress = INT64-toIP((IP-toINT64($desktopNetworkDetails.broadcast)) - 1)
    $desktopDefaultGateway = INT64-toIP((IP-toINT64($DesktopNetwork)) + 1)

    # Configure RDS DHCP Settings
    $RdsNetworkDetails = Get-NetworkRange -Network $RdsNetwork -Subnetmask $RdsSubnetMask
    $RdsStartAddress = INT64-toIP((IP-toINT64($RdsNetwork)) + 3)
    $RdsEndAddress = INT64-toIP((IP-toINT64($RdsNetworkDetails.broadcast)) - 1)
    $RdsDefaultGateway = INT64-toIP((IP-toINT64($RdsNetwork)) + 1)

    if (-not ($edgeDhcpConfig.SelectSingleNode("//dhcp/ipPools/ipPool[ipRange='$($desktopStartAddress)-$($desktopEndAddress)']"))) {
        [System.XML.XMLDocument]$xmlDoc = New-Object System.XML.XMLDocument
        [System.XML.XMLElement]$xmlIpPool = $XMLDoc.CreateElement("ipPool")
        $xmlDoc.appendChild($xmlIpPool) | out-null
        Add-XmlElement -xmlRoot $xmlIpPool -xmlElementName "autoConfigureDNS" -xmlElementText "false"
        Add-XmlElement -xmlRoot $xmlIpPool -xmlElementName "primaryNameServer" -xmlElementText $dnsServer
        Add-XmlElement -xmlRoot $xmlIpPool -xmlElementName "subnetMask" -xmlElementText $desktopSubnetMask
        Add-XmlElement -xmlRoot $xmlIpPool -xmlElementName "ipRange" -xmlElementText "$($desktopStartAddress)-$($desktopEndAddress)"
        Add-XmlElement -xmlRoot $xmlIpPool -xmlElementName "defaultGateway" -xmlElementText $desktopDefaultGateway
        
        $importedDhcpIpPool = $edgeDhcpConfig.ImportNode($xmlIpPool, $True)
        $xmldDhcpIpPoolsRoot = $edgeDhcpConfig.SelectSingleNode("//dhcp/ipPools")
        $xmldDhcpIpPoolsRoot.appendChild($importedDhcpIpPool) | out-null

        write-host "Updating Edge Desktop DHCP configuration `n" -ForegroundColor Green
        Invoke-NsxRestMethod -method PUT -URI $uriEdgeDhcpConfig -body $edgeDhcpConfig.OuterXml 
    }
    if (-not ($edgeDhcpConfig.SelectSingleNode("//dhcp/ipPools/ipPool[ipRange='$($RdsStartAddress)-$($RdsEndAddress)']"))) {
        [System.XML.XMLDocument]$xmlDoc = New-Object System.XML.XMLDocument
        [System.XML.XMLElement]$xmlIpPool = $XMLDoc.CreateElement("ipPool")
        $xmlDoc.appendChild($xmlIpPool) | out-null
        Add-XmlElement -xmlRoot $xmlIpPool -xmlElementName "autoConfigureDNS" -xmlElementText "false"
        Add-XmlElement -xmlRoot $xmlIpPool -xmlElementName "primaryNameServer" -xmlElementText $dnsServer
        Add-XmlElement -xmlRoot $xmlIpPool -xmlElementName "subnetMask" -xmlElementText $RdsSubnetMask
        Add-XmlElement -xmlRoot $xmlIpPool -xmlElementName "ipRange" -xmlElementText "$($RdsStartAddress)-$($RdsEndAddress)"
        Add-XmlElement -xmlRoot $xmlIpPool -xmlElementName "defaultGateway" -xmlElementText $RdsDefaultGateway
        
        $importedDhcpIpPool = $edgeDhcpConfig.ImportNode($xmlIpPool, $True)
        $xmldDhcpIpPoolsRoot = $edgeDhcpConfig.SelectSingleNode("//dhcp/ipPools")
        $xmldDhcpIpPoolsRoot.appendChild($importedDhcpIpPool) | out-null     
        
        write-host "Updating Edge RDS DHCP configuration `n" -ForegroundColor Green
        Invoke-NsxRestMethod -method PUT -URI $uriEdgeDhcpConfig -body $edgeDhcpConfig.OuterXml 
    }
}




If($deployMicroSeg){
    #####################################
    # Microseg config

    write-host -foregroundcolor Green "Getting Services"

    # Assume these services exist which they do in a default NSX deployment.
    $httpservice = New-NsxService -name "tcp-80" -protocol tcp -port "80"
    
    #Create Security Tags
    $HorizonSt = New-NsxSecurityTag -name $DesktopStName
    #$AppSt = New-NsxSecurityTag -name $AppStName
    #$DbSt = New-NsxSecurityTag -name $DbStName


    # Create IP Sets
    write-host -foregroundcolor "Green" "Creating Source IP Groups"
    $HorizonVIP_IpSet = New-NsxIPSet -Name $DesktopVIP_IpSet_Name -IPAddresses $EdgeInternalSecondaryAddress
    $InternalESG_IpSet = New-NsxIPSet -name $DesktopInternalESG_IpSet_Name -IPAddresses $Edge01InternalPrimaryAddress

    write-host -foregroundcolor "Green" "Creating Security Groups"

    #Create SecurityGroups and with static includes
    $HorizonSg = New-NsxSecurityGroup -name $DesktopSgName -description $DesktopSgDescription -includemember $HorizonSt
	
	$AppSg = New-NsxSecurityGroup -name $AppSgName -description $AppSgDescription -includemember $AppSt
    $DbSg = New-NsxSecurityGroup -name $DbSgName -description $DbSgDescription -includemember $DbSt
    $BooksSg = New-NsxSecurityGroup -name $vAppSgName -description $vAppSgName -includemember $HorizonSg, $AppSg, $DbSg
	
    # Apply Security Tag to VM's for Security Group membership

    $WebVMs = Get-Vm | Where-Object {$_.name -match ("cs0")}
    #$AppVMs = Get-Vm | ? {$_.name -match ("App0")}
    #$DbVMs = Get-Vm | ? {$_.name -match ("Db0")}

    $HorizonSt | New-NsxSecurityTagAssignment -ApplyToVm -VirtualMachine $WebVMs | Out-Null
    #$AppSt | New-NsxSecurityTagAssignment -ApplyToVm -VirtualMachine $AppVMs | Out-Null
    #$DbSt | New-NsxSecurityTagAssignment -ApplyToVm -VirtualMachine $DbVMs | Out-Null

    #Building firewall section with value defined in $DesktopFirewallSectionName
    write-host -foregroundcolor "Green" "Creating Firewall Section"

    $FirewallSection = new-NsxFirewallSection $DesktopFirewallSectionName

    #Actions
    $AllowTraffic = "allow"
    $DenyTraffic = "deny"

    #Allows Web VIP to reach WebTier
    write-host -foregroundcolor "Green" "Creating Web Tier rule"
    $SourcesRule = get-nsxfirewallsection $DesktopFirewallSectionName | New-NSXFirewallRule -Name "VIP to Web" -Source $InternalESG_IpSet -Destination $HorizonSg -Service $HttpService -Action $AllowTraffic -AppliedTo $HorizonSg -position bottom

    #Allows Web tier to reach App Tier via the APP VIP and then the NAT'd vNIC address of the Edge
    write-host -foregroundcolor "Green" "Creating Web to App Tier rules"
    $WebToAppVIP = get-nsxfirewallsection $DesktopFirewallSectionName | New-NsxFirewallRule -Name "$DesktopSgName to App VIP" -Source $HorizonSg -Destination $HorizonVIP_IpSet -Service $HttpService -Action $AllowTraffic -AppliedTo $HorizonSg, $AppSg -position bottom
    $ESGToApp = get-NsxFirewallSection $DesktopFirewallSectionName | New-NsxFirewallRule -Name "App ESG interface to $AppSgName" -Source $InternalEsg_IpSet -Destination $appSg -service $HttpService -Action $Allowtraffic -AppliedTo $AppSg -position bottom

    #Allows App tier to reach DB Tier directly
    write-host -foregroundcolor "Green" "Creating Db Tier rules"
    $AppToDb = get-nsxfirewallsection $DesktopFirewallSectionName | New-NsxFirewallRule -Name "$AppSgName to $DbSgName" -Source $AppSg -Destination $DbSg -Service $MySqlService -Action $AllowTraffic -AppliedTo $AppSg, $DbSG -position bottom

    write-host -foregroundcolor "Green" "Creating deny all applied to $vAppSgName"
    #Default rule that wraps around all VMs within the topolgoy - application specific DENY ALL
    $BooksDenyAll = get-nsxfirewallsection $DesktopFirewallSectionName | New-NsxFirewallRule -Name "Deny All Books" -Action $DenyTraffic -AppliedTo $BooksSg -position bottom -EnableLogging -tag "$BooksSG"
    write-host -foregroundcolor "Green" "Books application deployment complete."
}

Write-Host "`n The deployment and configuraiton of NSX is complete `n" -ForegroundColor Green

$vSpherePortGroup = Get-VDPortgroup | Where-Object {$_.Name -like "*$($HorizonLs.vdnId)-$($HorizonLs.Name)"} | Select-Object Name
Write-Host "The Name of the Horizon Management Network is: $vSpherePortGroup" 
return $vSpherePortGroup