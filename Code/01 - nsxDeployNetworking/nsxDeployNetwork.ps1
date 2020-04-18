<#
========================================================================
 Created on:   05/25/2018
 Created by:   Tai Ratcliff
 Organization: VMware	 
 Filename:     nsxDeployNetwork.ps1
 Example:      nsxDeployNetwork.ps1 -eucConfigJson eucConfigXML.json
========================================================================
#>
param( 
    [ValidateScript({Test-Path -Path $_})]
    [String]$eucConfigJson = "$PsScriptRoot\..\..\eucConfig.json",
    [switch]$validate,
    [switch]$rollback
    )

$eucConfig = Get-Content -Path $eucConfigJson | ConvertFrom-Json

#Clear-Host 

#############################################
#############################################
# NSX Infrastructure Configuration.
$NsxManagerServer = If($eucConfig.nsxConfig.nsxManagerServer){$eucConfig.nsxConfig.nsxManagerServer} Else {throw "NSX Manager Server not set"}
$NsxManagerPassword = If($eucConfig.nsxConfig.nsxManagerPassword){$eucConfig.nsxConfig.nsxManagerPassword} Else {throw "NSX Manager Password not set"}
$MgmtvCenterServer = If($eucConfig.mgmtConfig.mgmtvCenter){$eucConfig.mgmtConfig.mgmtvCenter} Else {throw "vCenter Server not set"}

#vSphereDetails for NSX
$MgmtvCenterUserName = If($eucConfig.horizonServiceAccount.Username){$eucConfig.horizonServiceAccount.Username} Else {throw "Management vCenter Username not set"}
$MgmtvCenterPassword = If($eucConfig.horizonServiceAccount.Password){$eucConfig.horizonServiceAccount.Password} Else {throw "Management vCenter Password not set"}
$MgmtClusterName = If($eucConfig.horizonConfig.connectionServers.mgmtCluster){$eucConfig.horizonConfig.connectionServers.mgmtCluster} Else {throw "Management vCenter cluster name not set"}
$MgmtVdsName = If($eucConfig.horizonConfig.connectionServers.mgmtVDS){$eucConfig.horizonConfig.connectionServers.mgmtVDS} Else {throw "Management VDS name not set"}
$mgmtEdgeClusterName = If($eucConfig.nsxConfig.mgmtEdgeClusterName){$eucConfig.nsxConfig.mgmtEdgeClusterName} Else {throw "Management edge cluster name not set"}
$mgmtEdgeDatastoreName = If($eucConfig.nsxConfig.mgmtEdgeDatastoreName){$eucConfig.nsxConfig.mgmtEdgeDatastoreName} Else {throw "Management edge datastore name not set"}
$mgmtNsxUplinkPortGroup01Name = If($eucConfig.nsxConfig.mgmtNsxUplinkPortGroup01Name){$eucConfig.nsxConfig.mgmtNsxUplinkPortGroup01Name} Else {throw "Management NSX uplink 01 port group name not set"}
$mgmtNsxUplinkPortGroup02Name = If($eucConfig.nsxConfig.mgmtNsxUplinkPortGroup02Name){$eucConfig.nsxConfig.mgmtNsxUplinkPortGroup02Name} Else {throw "Management NSX uplink 02 port group name not set"}
$mgmtNsxFolderName = If($eucConfig.nsxConfig.mgmtNsxFolderName){$eucConfig.nsxConfig.mgmtNsxFolderName} Else {throw "Management NSX folder name not set"}
$mgmtDatacenterName = If($eucConfig.mgmtConfig.mgmtDatacenterName){$eucConfig.mgmtConfig.mgmtDatacenterName} Else {throw "Management datacenter name not set"}

#############################################
#############################################
# Logical Topology environment

$tor01UplinkProtocolAddress = If($eucConfig.nsxConfig.mgmtTor01UplinkProtocolAddress){$eucConfig.nsxConfig.mgmtTor01UplinkProtocolAddress} Else {throw "Management Top of Rack uplink 01 address not set"}
$tor02UplinkProtocolAddress = If($eucConfig.nsxConfig.mgmtTor02UplinkProtocolAddress){$eucConfig.nsxConfig.mgmtTor02UplinkProtocolAddress} Else {throw "Management Top of Rack uplink 02 address not set"}
$Edge01Uplink01PrimaryAddress = If($eucConfig.nsxConfig.mgmtEdge01Uplink01PrimaryAddress){$eucConfig.nsxConfig.mgmtEdge01Uplink01PrimaryAddress} Else {throw "Management edge 01 uplink 01 address not set"}
$Edge01Uplink02PrimaryAddress = If($eucConfig.nsxConfig.mgmtEdge01Uplink02PrimaryAddress){$eucConfig.nsxConfig.mgmtEdge01Uplink02PrimaryAddress} Else {throw "Management edge 01 uplink 02 address not set"}
$Edge02Uplink01PrimaryAddress = If($eucConfig.nsxConfig.mgmtEdge02Uplink01PrimaryAddress){$eucConfig.nsxConfig.mgmtEdge02Uplink01PrimaryAddress} Else {throw "Management edge 02 uplink 01 address not set"}
$Edge02Uplink02PrimaryAddress = If($eucConfig.nsxConfig.mgmtEdge02Uplink02PrimaryAddress){$eucConfig.nsxConfig.mgmtEdge02Uplink02PrimaryAddress} else {throw "Management edge 02 uplink 02 address not set"}
$bgpPassword = $eucConfig.nsxConfig.bgpPassword
$uplinkASN01 = If($eucConfig.nsxConfig.mgmtUplinkASN01){$eucConfig.nsxConfig.mgmtUplinkASN01} Else {throw "Management uplink ASN 01 not set"}
$uplinkASN02 = If($eucConfig.nsxConfig.mgmtUplinkASN02){$eucConfig.nsxConfig.mgmtUplinkASN02} Else {throw "Management uplink ASN 02 not set"}
$LocalASN = If($eucConfig.nsxConfig.mgmtLocalASN){$eucConfig.nsxConfig.mgmtLocalASN} Else {throw "Management NSX local ASN not set"}
$keepAliveTimer = If($eucConfig.nsxConfig.mgmtKeepAliveTimer){$eucConfig.nsxConfig.mgmtKeepAliveTimer} Else {"1"}
$holdDownTimer = If($eucConfig.nsxConfig.mgmtHoldDownTimer){$eucConfig.nsxConfig.mgmtHoldDownTimer} Else {"3"}
$AppliancePassword = If($eucConfig.nsxConfig.mgmtEdgePassword){$eucConfig.nsxConfig.mgmtEdgePassword} Else {throw "Management NSX edge applicance password not set"}

$mgmtTransitLsName = If($eucConfig.nsxConfig.mgmtTransitLsName){$eucConfig.nsxConfig.mgmtTransitLsName} Else {throw "Management NSX transit logical switch name not set"}
$mgmtEdgeHAPortGroupName = If($eucConfig.nsxConfig.mgmtEdgeHAPortGroupName){$eucConfig.nsxConfig.mgmtEdgeHAPortGroupName} Else {throw "Management edge HA port group not set"}
$mgmtEUC_MGMT_Network = If($eucConfig.nsxConfig.mgmtEUC_MGMT_Network){$eucConfig.nsxConfig.mgmtEUC_MGMT_Network} Else {throw "EUC management network network name not set"}
$mgmtEdge01Name = If($eucConfig.nsxConfig.mgmtEdge01Name){$eucConfig.nsxConfig.mgmtEdge01Name} Else {throw "Management edge 01 name not set"}
$mgmtEdge02Name = If($eucConfig.nsxConfig.mgmtEdge02Name){$eucConfig.nsxConfig.mgmtEdge02Name} Else {throw "Management edge 02 name not set"}
$mgmtLdrName = If($eucConfig.nsxConfig.mgmtLdrName){$eucConfig.nsxConfig.mgmtLdrName} Else {throw "Management distributed logical router name not set"}
$mgmtEUCTransportZoneName = If($eucConfig.nsxConfig.mgmtEUCTransportZoneName){$eucConfig.nsxConfig.mgmtEUCTransportZoneName} Else {throw "Management EUC transport zone name not set"}

#Loical Networking Topology
$mgmtEdge01InternalPrimaryAddress = If($eucConfig.nsxConfig.mgmtEdge01InternalPrimaryAddress){$eucConfig.nsxConfig.mgmtEdge01InternalPrimaryAddress} Else {throw "Management edge 01 internal primary IP address not set"}
$mgmtEdge02InternalPrimaryAddress = If($eucConfig.nsxConfig.mgmtEdge02InternalPrimaryAddress){$eucConfig.nsxConfig.mgmtEdge02InternalPrimaryAddress} Else {throw "Management edge 02 internal primary IP address not set"}
$mgmtLdrUplinkPrimaryAddress = If($eucConfig.nsxConfig.mgmtLdrUplinkPrimaryAddress){$eucConfig.nsxConfig.mgmtLdrUplinkPrimaryAddress} Else {throw "Management distributed logical router uplink primary IP address not set"}
$mgmtLdrUplinkProtocolAddress = If($eucConfig.nsxConfig.mgmtLdrUplinkProtocolAddress){$eucConfig.nsxConfig.mgmtLdrUplinkProtocolAddress} Else {throw "Management distributed logical router uplink protocol IP address not set"}
$mgmtLdrEUCMGMTPrimaryAddress = If($eucConfig.nsxConfig.mgmtLdrEUCMGMTPrimaryAddress){$eucConfig.nsxConfig.mgmtLdrEUCMGMTPrimaryAddress} Else {throw "EUC management distributed locical router primary IP address not set"}
$mgmtDefaultSubnetBits = If($eucConfig.nsxConfig.mgmtDefaultSubnetBits){$eucConfig.nsxConfig.mgmtDefaultSubnetBits} Else {throw "Default management subnet not set"}
$mgmtDlrHaDatastoreName = If($eucConfig.nsxConfig.mgmtDlrHaDatastoreName){$eucConfig.nsxConfig.mgmtDlrHaDatastoreName} Else {throw "Management distributed logical router HA datastore name not set"}

#Connection Server VMs
$csServers = If($eucConfig.horizonConfig.ConnectionServers.horizonCS){$eucConfig.horizonConfig.ConnectionServers.horizonCS} Else {throw "Connection Servers are not set"}

##LoadBalancer
$horizonLbEdgeName = $eucConfig.nsxConfig.horizonLbEdgeName
$horizonLbPrimaryIPAddress = $eucConfig.nsxConfig.horizonLbPrimaryIPAddress
$horizonVipIp = $eucConfig.nsxConfig.horizonVipIp
$horizonLbAlgorithm = $eucConfig.nsxConfig.horizonLbAlgorithm
$horizonLbPoolName = $eucConfig.nsxConfig.horizonLbPoolName
$horizonVipName = $eucConfig.nsxConfig.horizonVipName
$horizonAppProfileName = $eucConfig.nsxConfig.horizonAppProfileName
$horizonVipProtocol = $eucConfig.nsxConfig.horizonVipProtocol
$horizonHttpsPort = $eucConfig.nsxConfig.horizonHttpsPort
$horizonLBMonitorName = $eucConfig.nsxConfig.horizonLBMonitorName

## Security Groups
$horizonSgName = $eucConfig.nsxConfig.horizonSgName
$horizonSgDescription = $eucConfig.nsxConfig.horizonSgDescription

## Security Tags
$horizonStName = $eucConfig.nsxConfig.horizonStName

##IPset
$horizonVIP_IpSet_Name = $eucConfig.nsxConfig.horizonVIP_IpSet_Name
$horizonInternalESG_IpSet_Name = $eucConfig.nsxConfig.horizonInternalESG_IpSet_Name
##DFW
$horizonFirewallSectionName = $eucConfig.nsxConfig.horizonFirewallSectionName


###############################################
# Do Not modify below here.
###############################################
###############################################
# Validation
# Connect to vCenter
# Check for PG, DS, Cluster

#Get Connection required.
try {
    #Connect-NsxServer -server $NsxManagerServer -Username 'admin' -password $NsxManagerPassword -VIUsername $MgmtvCenterUserName -VIPassword $MgmtvCenterPassword -ViWarningAction Ignore -DebugLogging | out-null
    Connect-NsxServer -vCenterServer $MgmtvCenterServer -Username $MgmtvCenterUserName -Password $MgmtvCenterPassword | out-null

} catch {
    Throw "Failed connecting.  Check connection details and try again.  $_"
}


If($rollback){
    Get-NsxEdge | Where-Object{($_.Name -eq $mgmtEdge01Name) -or ($_.Name -eq $mgmtEdge02Name) -or ($_.Name -eq $horizonLbEdgeName)} | Remove-NsxEdge -Confirm:$False
    Get-NsxLogicalRouter | Where-Object{$_.name -eq $mgmtLdrName} | Remove-NsxLogicalRouter -Confirm:$False
    Start-Sleep 2
    Get-NsxLogicalSwitch | Where-Object{($_.name -eq $HorizonLsName) -or ($_.name -eq $mgmtTransitLsName) -or ($_.Name -eq $mgmtEUC_MGMT_Network)} | Remove-NsxLogicalSwitch -Confirm:$False
    If(Get-NsxLogicalSwitch $mgmtEdgeHAPortGroupName){
        Get-NsxLogicalSwitch $mgmtEdgeHAPortGroupName | Remove-NsxLogicalSwitch -Confirm:$False
    }
    Get-VDPortgroup | Where-Object{($_.Name -eq $mgmtNsxUplinkPortGroup01Name) -or ($_.Name -eq $mgmtNsxUplinkPortGroup02Name)} | Remove-VDPortGroup -Confirm:$False
    If(Get-Folder $mgmtNsxFolderName{
        Remove-Folder $mgmtNsxFolderName -DeletePermanently -Confirm:$false
    }
    Write-Host "Rolled back NSX configuraiton `n" -ForegroundColor Green
    Exit
}

    #Check that the vCenter env looks correct for deployment.
    try {
        $MgmtCluster = Get-Cluster $MgmtClusterName -errorAction Stop
        $mgmtEdgeCluster = get-cluster $mgmtEdgeClusterName -errorAction Stop
        $mgmtEdgeDatastore = get-datastore $mgmtEdgeDatastoreName -errorAction Stop
        $mgmtDlrHADatastore = get-datastore $mgmtDlrHaDatastoreName -errorAction Stop
    }
    catch {
        Throw "Failed validating vSphere Environment. $_"
    }

    try {
        #Failed deployment stuff
		if ( Get-NsxLogicalSwitch $mgmtEUC_MGMT_Network ) {
            throw "Logical Switch already exists.  Please remove and try again."
        }
        if ( Get-NsxLogicalSwitch $mgmtTransitLsName ) {
            throw "Logical Switch already exists.  Please remove and try again."
        }
        if ( (get-nsxservice "tcp-80") -or (get-nsxservice "tcp-3306" ) ) {
            throw "Custom services already exist.  Please remove and try again."
        }
        if ( get-nsxedge $mgmtEdge01Name ) {
            throw "Edge already exists.  Please remove and try again."
        }
        if ( get-nsxlogicalrouter $mgmtLdrName ) {
            throw "Logical Router already exists.  Please remove and try again."
        }
        if ( get-nsxsecurityGroup $horizonSgName ) {
            throw "Security Group exists.  Please remove and try again."
        }
        if ( get-nsxfirewallsection $horizonFirewallSectionName ) {
            throw "Firewall Section already exists.  Please remove and try again."
        }
        if ( get-nsxsecuritytag $horizonStName ) {
            throw "Security Tag already exists.  Please remove and try again."
        }
        if ( Get-nsxipset $horizonVIP_IpSet_Name ) {
            throw "IPSet already exists.  Please remove and try again."
        }
        if ( Get-nsxipset $horizonInternalESG_IpSet_Name ) {
            throw "IPSet already exists.  Please remove and try again."
        }
    }
    catch {
        Throw "Failed validating environment for Horizon deployment.  $_"
    }


if($eucConfig.deployNSX){
    #Prepare for NSX Install/Configuration
    #Create Uplink distributed port groups in vCenter
    if(!(get-vdportgroup $mgmtNsxUplinkPortGroup01Name -errorAction Ignore)){
        write-host -foregroundcolor Green "Creating NSX Uplink Port Group 1. `n"
        Get-VDSwitch -Name $MgmtVdsName | New-VDPortgroup -Name $mgmtNsxUplinkPortGroup01Name -NumPorts 10 -VLanId 145 -PortBinding Static | Out-Null
        $EdgeUplink01Network = Get-VDPortgroup $mgmtNsxUplinkPortGroup01Name
        Get-VDUplinkTeamingPolicy -VDPortgroup $mgmtNsxUplinkPortGroup01Name | Set-VDUplinkTeamingPolicy -LoadBalancingPolicy "LoadBalanceLoadBased" -ActiveUplinkPort "dvUplink1" -StandbyUplinkPort "dvUplink2" | Out-Null
    }
    if(!(get-vdportgroup $mgmtNsxUplinkPortGroup02Name -errorAction Ignore)){
        write-host -foregroundcolor Green "Creating NSX Uplink Port Group 2. `n"
        Get-VDSwitch -Name $MgmtVdsName | New-VDPortgroup -Name $mgmtNsxUplinkPortGroup02Name -NumPorts 10 -VLanId 145 -PortBinding Static | Out-Null
        $EdgeUplink02Network = Get-VDPortgroup $mgmtNsxUplinkPortGroup02Name
        Get-VDUplinkTeamingPolicy -VDPortgroup $mgmtNsxUplinkPortGroup02Name | Set-VDUplinkTeamingPolicy -LoadBalancingPolicy "LoadBalanceLoadBased" -ActiveUplinkPort "dvUplink2" -StandbyUplinkPort "dvUplink1" | Out-Null
    }

    if(get-Folder -Name $mgmtNsxFolderName -ErrorAction Ignore){
        Write-Host "Found an existing $mgmtNsxFolderName VM Folder in vCenter. This is where the Connection Servers will be deployed." -ForegroundColor Yellow `n
    } Else {
        Write-Host "The $mgmtNsxFolderName VM folder does not exist, creating a new folder" -ForegroundColor Yellow `n
        (Get-View (Get-View -viewtype datacenter -filter @{"name"="$mgmtDatacenterName"}).vmfolder).CreateFolder("$mgmtNsxFolderName") | Out-Null
    }

    try {
        #Configure TZ and add clusters.
        If(!(Get-NsxTransportZone -Name $mgmtEUCTransportZoneName)){
            Write-Host "Creating NSX Transport Zone $mgmtEUCTransportZoneName. `n" -ForegroundColor Green
            New-NsxTransportZone -Name $mgmtEUCTransportZoneName -Cluster $MgmtCluster -ControlPlaneMode "HYBRID_MODE" | out-null
        }
    }
    catch {
        Throw  "Failed configuring Transport Zone.  $_"
    }

    write-host -foregroundcolor Green "`nNSX Infrastructure Config Complete`n"


    ######################################
    ######################################
    ## Topology Deployment

    write-host -foregroundcolor Green "NSX Horizon deployment beginning.`n"
    ######################################
    #Logical Switches

    write-host -foregroundcolor "Green" "Creating Logical Switches..."

    ## Creates logical switches
    $TransitLs = Get-NsxTransportZone $mgmtEUCTransportZoneName | New-NsxLogicalSwitch $mgmtTransitLsName
    $HorizonLs = Get-NsxTransportZone $mgmtEUCTransportZoneName | New-NsxLogicalSwitch $mgmtEUC_MGMT_Network
    
    # Check if the user defined an Edge HA Port group that already exists .e.g. The Management DVS Port Group. If not, create a new Logical Switch
	if(($EdgeHAPortGroup = Get-VDPortgroup -VDSwitch $MgmtVdsName $mgmtEdgeHAPortGroupName -ErrorAction Ignore) -or ($EdgeHAPortGroup = Get-NsxLogicalSwitch $mgmtEdgeHAPortGroupName -ErrorAction Ignore)){
		Write-Host -foregroundcolor "Green" "Found an existing port group or Logical Switch called $mgmtEdgeHAPortGroupName. This will be used for the Edge HA Management."
    } Else {
		$EdgeHAPortGroup = Get-NsxTransportZone $mgmtEUCTransportZoneName | New-NsxLogicalSwitch $mgmtEdgeHAPortGroupName
	}
    

    ######################################
    # Provision and Configure DLR

    # DLR Appliance has the uplink router interface created first.
    write-host -foregroundcolor "Green" "Creating DLR"
    $LdrvNic0 = New-NsxLogicalRouterInterfaceSpec -type Uplink -Name $mgmtTransitLsName -ConnectedTo $TransitLs -PrimaryAddress $mgmtLdrUplinkPrimaryAddress -SubnetPrefixLength $mgmtDefaultSubnetBits

    # The DLR is created with the first vnic defined, and the datastore and cluster on which the Control VM will be deployed.
    $Ldr = New-NsxLogicalRouter -name $mgmtLdrName -ManagementPortGroup $EdgeHAPortGroup -interface $LdrvNic0 -cluster $mgmtEdgeCluster -datastore $mgmtEdgeDatastore -EnableHA -HADatastore $mgmtdlrHADatastore

    ## Adding DLR interfaces after the DLR has been deployed. This can be done any time if new interfaces are required.
    write-host -foregroundcolor Green "Adding DLR interfaces after the DLR has been deployed"
    $Ldr | New-NsxLogicalRouterInterface -Type Internal -name $mgmtEUC_MGMT_Network -ConnectedTo $HorizonLs -PrimaryAddress $mgmtLdrEUCMGMTPrimaryAddress -SubnetPrefixLength $mgmtDefaultSubnetBits | out-null

    ######################################
    ##Configure DLR Routing
    Get-NsxLogicalRouter $mgmtLdrName | Get-NsxLogicalRouterRouting | Set-NsxLogicalRouterRouting -confirm:$false -EnableEcmp -RouterId $mgmtLdrUplinkPrimaryAddress -ProtocolAddress $mgmtLdrUplinkProtocolAddress -LocalAS $LocalASN -ForwardingAddress $mgmtLdrUplinkPrimaryAddress -EnableBgp -EnableLogging | out-null
    If($bgpPassword){    
        Get-NsxLogicalRouter $mgmtLdrName | Get-NsxLogicalRouterRouting | New-NsxLogicalRouterBgpNeighbour -RemoteAS $LocalASN -IpAddress $mgmtEdge01InternalPrimaryAddress -ForwardingAddress $mgmtLdrUplinkPrimaryAddress -ProtocolAddress $mgmtLdrUplinkProtocolAddress -HoldDownTimer $holdDownTimer -KeepAliveTimer $keepAliveTimer -Confirm:$false -Password $bgpPassword | out-null
        Get-NsxLogicalRouter $mgmtLdrName | Get-NsxLogicalRouterRouting | New-NsxLogicalRouterBgpNeighbour -RemoteAS $LocalASN -IpAddress $mgmtEdge02InternalPrimaryAddress -ForwardingAddress $mgmtLdrUplinkPrimaryAddress -ProtocolAddress $mgmtLdrUplinkProtocolAddress -HoldDownTimer $holdDownTimer -KeepAliveTimer $keepAliveTimer -Confirm:$false -Password $bgpPassword | out-null
    } Else {
        Get-NsxLogicalRouter $mgmtLdrName | Get-NsxLogicalRouterRouting | New-NsxLogicalRouterBgpNeighbour -RemoteAS $LocalASN -IpAddress $mgmtEdge01InternalPrimaryAddress -ForwardingAddress $mgmtLdrUplinkPrimaryAddress -ProtocolAddress $mgmtLdrUplinkProtocolAddress -HoldDownTimer $holdDownTimer -KeepAliveTimer $keepAliveTimer -Confirm:$false | out-null
        Get-NsxLogicalRouter $mgmtLdrName | Get-NsxLogicalRouterRouting | New-NsxLogicalRouterBgpNeighbour -RemoteAS $LocalASN -IpAddress $mgmtEdge02InternalPrimaryAddress -ForwardingAddress $mgmtLdrUplinkPrimaryAddress -ProtocolAddress $mgmtLdrUplinkProtocolAddress -HoldDownTimer $holdDownTimer -KeepAliveTimer $keepAliveTimer -Confirm:$false | out-null
    }
        Get-NsxLogicalRouter $mgmtLdrName | Get-NsxLogicalRouterRouting | Set-NsxLogicalRouterRouting -EnableBgpRouteRedistribution -Confirm:$false | out-null
        Get-NsxLogicalRouter $mgmtLdrName | Get-NsxLogicalRouterRouting | New-NsxLogicalRouterRedistributionRule -Learner bgp -FromConnected -Action permit -Confirm:$false | Out-Null
    ######################################
    # Provision and Configure Edges

    # EDGE01 -ECMP
    ## Defining the uplink and internal interfaces to be used when deploying the edge. Note there are two IP addreses on these interfaces. $EdgeInternalSecondaryAddress and $EdgeUplink01SecondaryAddress are the VIPs
    $edgevnic0 = New-NsxEdgeinterfacespec -index 0 -Name "Uplink01" -type Uplink -ConnectedTo $EdgeUplink01Network -PrimaryAddress $Edge01Uplink01PrimaryAddress -SubnetPrefixLength $mgmtDefaultSubnetBits
	$edgevnic1 = New-NsxEdgeinterfacespec -index 1 -Name "Uplink02" -type Uplink -ConnectedTo $EdgeUplink02Network -PrimaryAddress $Edge01Uplink02PrimaryAddress -SubnetPrefixLength $mgmtDefaultSubnetBits
    $edgevnic2 = New-NsxEdgeinterfacespec -index 2 -Name $mgmtTransitLsName -type Internal -ConnectedTo $TransitLs -PrimaryAddress $mgmtEdge01InternalPrimaryAddress -SubnetPrefixLength $mgmtDefaultSubnetBits
    ## Deploy appliance with the defined uplinks
    write-host -foregroundcolor "Green" "Creating $mgmtEdge01Name"
    $Edge1 = New-NsxEdge -name $mgmtEdge01Name -cluster $mgmtEdgeCluster -datastore $mgmtEdgeDatastore -Interface $edgevnic0, $edgevnic1, $edgevnic2 -Password $AppliancePassword -FwDefaultPolicyAllow -FwEnabled:$false
    
    # EDGE02 -ECMP
    ## Defining the uplink and internal interfaces to be used when deploying the edge. Note there are two IP addreses on these interfaces. $EdgeInternalSecondaryAddress and $EdgeUplink01SecondaryAddress are the VIPs
    $edgevnic0 = New-NsxEdgeinterfacespec -index 0 -Name "Uplink01" -type Uplink -ConnectedTo $EdgeUplink01Network -PrimaryAddress $Edge02Uplink01PrimaryAddress -SubnetPrefixLength $mgmtDefaultSubnetBits
	$edgevnic1 = New-NsxEdgeinterfacespec -index 1 -Name "Uplink02" -type Uplink -ConnectedTo $EdgeUplink02Network -PrimaryAddress $Edge02Uplink02PrimaryAddress -SubnetPrefixLength $mgmtDefaultSubnetBits
    $edgevnic2 = New-NsxEdgeinterfacespec -index 2 -Name $mgmtTransitLsName -type Internal -ConnectedTo $TransitLs -PrimaryAddress $mgmtEdge02InternalPrimaryAddress -SubnetPrefixLength $mgmtDefaultSubnetBits
    ## Deploy appliance with the defined uplinks
    write-host -foregroundcolor "Green" "Creating $mgmtEdge02Name"
    $Edge2 = New-NsxEdge -name $mgmtEdge02Name -cluster $mgmtEdgeCluster -datastore $mgmtEdgeDatastore -Interface $edgevnic0, $edgevnic1, $edgevnic2 -Password $AppliancePassword -FwDefaultPolicyAllow -FwEnabled:$false

    
    ######################################
    ##Configure Edge Routing
    ## Edge 01
    Get-NSXEdge $mgmtEdge01Name | Get-NsxEdgeRouting | Set-NsxEdgeRouting -confirm:$false -EnableEcmp -RouterId $Edge01Uplink01PrimaryAddress -LocalAS $LocalASN -EnableBgp -EnableLogging | out-null
    If($bgpPassword){
        Get-NSXEdge $mgmtEdge01Name | Get-NsxEdgeRouting | New-NsxEdgeBgpNeighbour -RemoteAS $LocalASN -IpAddress $mgmtLdrUplinkProtocolAddress -KeepAliveTimer $keepAliveTimer -HoldDownTimer $holdDownTimer -Confirm:$false -Password $bgpPassword | out-null
        Get-NSXEdge $mgmtEdge01Name | Get-NsxEdgeRouting | New-NsxEdgeBgpNeighbour -RemoteAS $uplinkASN01 -IpAddress $tor01UplinkProtocolAddress -KeepAliveTimer $keepAliveTimer -HoldDownTimer $holdDownTimer -Confirm:$false -Password $bgpPassword | out-null
        Get-NSXEdge $mgmtEdge01Name | Get-NsxEdgeRouting | New-NsxEdgeBgpNeighbour -RemoteAS $uplinkASN02 -IpAddress $tor02UplinkProtocolAddress -KeepAliveTimer $keepAliveTimer -HoldDownTimer $holdDownTimer -Confirm:$false -Password $bgpPassword | out-null
    } else {
        Get-NSXEdge $mgmtEdge01Name | Get-NsxEdgeRouting | New-NsxEdgeBgpNeighbour -RemoteAS $LocalASN -IpAddress $mgmtLdrUplinkProtocolAddress -KeepAliveTimer $keepAliveTimer -HoldDownTimer $holdDownTimer -Confirm:$false | out-null
        Get-NSXEdge $mgmtEdge01Name | Get-NsxEdgeRouting | New-NsxEdgeBgpNeighbour -RemoteAS $uplinkASN01 -IpAddress $tor01UplinkProtocolAddress -KeepAliveTimer $keepAliveTimer -HoldDownTimer $holdDownTimer -Confirm:$false | out-null
        Get-NSXEdge $mgmtEdge01Name | Get-NsxEdgeRouting | New-NsxEdgeBgpNeighbour -RemoteAS $uplinkASN02 -IpAddress $tor02UplinkProtocolAddress -KeepAliveTimer $keepAliveTimer -HoldDownTimer $holdDownTimer -Confirm:$false | out-null
    }
    Get-NSXEdge $mgmtEdge01Name | Get-NsxEdgeRouting | Set-NsxEdgeRouting -EnableBgpRouteRedistribution -Confirm:$false | out-null
    Get-NsxEdge $mgmtEdge01Name | Get-NsxEdgeRouting | New-NsxEdgeRedistributionRule -Learner bgp -FromConnected -FromStatic -Action permit -Confirm:$false | Out-Null
    #Edge 02
    Get-NSXEdge $mgmtEdge02Name | Get-NsxEdgeRouting | Set-NsxEdgeRouting -confirm:$false -EnableEcmp -RouterId $Edge01Uplink02PrimaryAddress -LocalAS $LocalASN -EnableBgp -EnableLogging | out-null
    If($bgpPassword){
        Get-NSXEdge $mgmtEdge02Name | Get-NsxEdgeRouting | New-NsxEdgeBgpNeighbour -RemoteAS $LocalASN -IpAddress $mgmtLdrUplinkProtocolAddress -KeepAliveTimer $keepAliveTimer -HoldDownTimer $holdDownTimer -Confirm:$false -Password $bgpPassword | out-null
        Get-NSXEdge $mgmtEdge02Name | Get-NsxEdgeRouting | New-NsxEdgeBgpNeighbour -RemoteAS $uplinkASN01 -IpAddress $tor01UplinkProtocolAddress -KeepAliveTimer $keepAliveTimer -HoldDownTimer $holdDownTimer -Confirm:$false -Password $bgpPassword | out-null
        Get-NSXEdge $mgmtEdge02Name | Get-NsxEdgeRouting | New-NsxEdgeBgpNeighbour -RemoteAS $uplinkASN02 -IpAddress $tor02UplinkProtocolAddress -KeepAliveTimer $keepAliveTimer -HoldDownTimer $holdDownTimer -Confirm:$false -Password $bgpPassword | out-null
    } Else {
        
        Get-NSXEdge $mgmtEdge02Name | Get-NsxEdgeRouting | New-NsxEdgeBgpNeighbour -RemoteAS $LocalASN -IpAddress $mgmtLdrUplinkProtocolAddress -KeepAliveTimer $keepAliveTimer -HoldDownTimer $holdDownTimer -Confirm:$false | out-null
        Get-NSXEdge $mgmtEdge02Name | Get-NsxEdgeRouting | New-NsxEdgeBgpNeighbour -RemoteAS $uplinkASN01 -IpAddress $tor01UplinkProtocolAddress -KeepAliveTimer $keepAliveTimer -HoldDownTimer $holdDownTimer -Confirm:$false | out-null
        Get-NSXEdge $mgmtEdge02Name | Get-NsxEdgeRouting | New-NsxEdgeBgpNeighbour -RemoteAS $uplinkASN02 -IpAddress $tor02UplinkProtocolAddress -KeepAliveTimer $keepAliveTimer -HoldDownTimer $holdDownTimer -Confirm:$false | out-null
    }
    Get-NSXEdge $mgmtEdge02Name | Get-NsxEdgeRouting | Set-NsxEdgeRouting -EnableBgpRouteRedistribution -Confirm:$false | out-null
    Get-NsxEdge $mgmtEdge02Name | Get-NsxEdgeRouting | New-NsxEdgeRedistributionRule -Learner bgp -FromConnected -FromStatic -Action permit -Confirm:$false | Out-Null
}

If($eucConfig.nsxConfig.deployLoadBalancer){    
    #####################################
    # Load LoadBalancer
    # Deploy a 1-arm load balancer for Horizon Connection Servers
    write-host -foregroundcolor "Green" "Deploying new Load Balancer $horizonLbEdgeName"
    
    ## Defining the uplink and internal interfaces to be used when deploying the edge. Note there are two IP addreses on these interfaces. $EdgeInternalSecondaryAddress and $EdgeUplink01SecondaryAddress are the VIPs
    $edgevnic0 = New-NsxEdgeinterfacespec -index 0 -Name "OneArmLb" -type Uplink -ConnectedTo $HorizonLs -PrimaryAddress $horizonLbPrimaryIPAddress -SecondaryAddresses $horizonVipIp -SubnetPrefixLength $mgmtDefaultSubnetBits
    
    ## Deploy appliance with the defined uplinks
    $LbEdge = New-NsxEdge -name $horizonLbEdgeName -cluster $mgmtEdgeCluster -datastore $mgmtEdgeDatastore -Interface $edgevnic0 -Password $AppliancePassword -FwDefaultPolicyAllow
    
    # Enable NSX Load Balancer on the Edge
    Get-NsxEdge $horizonLbEdgeName | Get-NsxLoadBalancer | Set-NsxLoadBalancer -Enabled | out-null

    #Get default monitor.
    $monitor =  get-nsxedge $horizonLbEdgeName | Get-NsxLoadBalancer | Get-NsxLoadBalancerMonitor -Name $horizonLBMonitorName

    # Define pool members.  By way of example we will use two different methods for defining pool membership.  HorizonPool via predefine memberspec first...
    write-host -foregroundcolor Green "Creating Horizon Load Balancer Pool"

    # Create the Horizon pool
    $HorizonPool =  Get-NsxEdge $horizonLbEdgeName | Get-NsxLoadBalancer | New-NsxLoadBalancerPool -name $horizonLbPoolName -Description "Horizon Connection Server Pool" -Transparent:$false -Algorithm $horizonLbAlgorithm -Monitor $Monitor #-Memberspec $horizonPoolMember1, $horizonPoolMember2, $horizonPoolMember3
    
    ForEach($cs in $csServers.ConnectionServers.cs){
        Write-Host "Adding $($cs.Name) to the Load Balancer Pool" -ForegroundColor Blue
        #$horizonPoolMember = New-NsxLoadBalancerMemberSpec -name $cs.Name -IpAddress $cs.IP -Port $horizonHttpsPort
        Get-NsxEdge $horizonLbEdgeName | Get-NsxLoadBalancer | Get-NsxLoadBalancerPool $horizonLbPoolName | Add-NsxLoadBalancerPoolMember -Name $cs.Name -IpAddress $cs.IP -Port $horizonHttpsPort | Out-Null
    }

    
    # Create App Profiles. It is possible to use the same but for ease of operations this will be two here.
    write-host -foregroundcolor "Green" "Creating Application Profiles for Horizon"
    $HorizonAppProfile = Get-NsxEdge $horizonLbEdgeName | Get-NsxLoadBalancer | New-NsxLoadBalancerApplicationProfile -Name $horizonAppProfileName  -Type $horizonVipProtocol -SslPassthrough
    #$AppAppProfile = Get-NsxEdge $mgmtEdge01Name | Get-NsxLoadBalancer | new-NsxLoadBalancerApplicationProfile -Name $AppAppProfileName  -Type $horizonVipProtocol

    # Create the VIPs for the relevent HorizonPools. Using the Secondary interfaces.
    write-host -foregroundcolor "Green" "Creating VIPs"
    Get-NsxEdge $horizonLbEdgeName | Get-NsxLoadBalancer | Add-NsxLoadBalancerVip -name $horizonVipName -Description $horizonVipName -ipaddress $horizonVipIp -Protocol $horizonVipProtocol -Port $horizonHttpsPort -ApplicationProfile $HorizonAppProfile -DefaultPool $HorizonPool -AccelerationEnabled | out-null
    #Get-NsxEdge $mgmtEdge01Name | Get-NsxLoadBalancer | Add-NsxLoadBalancerVip -name $AppVipName -Description $AppVipName -ipaddress $EdgeInternalSecondaryAddress -Protocol $horizonVipProtocol -Port $horizonHttpsPort -ApplicationProfile $AppAppProfile -DefaultPool $AppPool -AccelerationEnabled | out-null
}

If($eucConfig.nsxConfig.enableMicroSeg){
    #####################################
    # Microseg config

    write-host -foregroundcolor Green "Getting Services"

    # Assume these services exist which they do in a default NSX deployment.
    $httpservice = New-NsxService -name "tcp-80" -protocol tcp -port "80"
    
    #Create Security Tags
    $HorizonSt = New-NsxSecurityTag -name $horizonStName

    # Create IP Sets
    write-host -foregroundcolor "Green" "Creating Source IP Groups"
    $HorizonVIP_IpSet = New-NsxIPSet -Name $horizonVIP_IpSet_Name -IPAddresses $EdgeInternalSecondaryAddress
    $InternalESG_IpSet = New-NsxIPSet -name $horizonInternalESG_IpSet_Name -IPAddresses $mgmtEdge01InternalPrimaryAddress

    write-host -foregroundcolor "Green" "Creating Security Groups"

    #Create SecurityGroups and with static includes
    $HorizonSg = New-NsxSecurityGroup -name $horizonSgName -description $horizonSgDescription -includemember $HorizonSt
	
	$AppSg = New-NsxSecurityGroup -name $AppSgName -description $AppSgDescription -includemember $AppSt
    $DbSg = New-NsxSecurityGroup -name $DbSgName -description $DbSgDescription -includemember $DbSt
    $BooksSg = New-NsxSecurityGroup -name $vAppSgName -description $vAppSgName -includemember $HorizonSg, $AppSg, $DbSg
	
    # Apply Security Tag to VM's for Security Group membership

    $WebVMs = Get-Vm | Where-Object {$_.name -match ("cs0")}

    $HorizonSt | New-NsxSecurityTagAssignment -ApplyToVm -VirtualMachine $WebVMs | Out-Null

    #Building firewall section with value defined in $horizonFirewallSectionName
    write-host -foregroundcolor "Green" "Creating Firewall Section"

    $FirewallSection = new-NsxFirewallSection $horizonFirewallSectionName

    #Actions
    $AllowTraffic = "allow"
    $DenyTraffic = "deny"

    #Allows Web VIP to reach WebTier
    write-host -foregroundcolor "Green" "Creating Web Tier rule"
    $SourcesRule = get-nsxfirewallsection $horizonFirewallSectionName | New-NSXFirewallRule -Name "VIP to Web" -Source $InternalESG_IpSet -Destination $HorizonSg -Service $HttpService -Action $AllowTraffic -AppliedTo $HorizonSg -position bottom

    #Allows Web tier to reach App Tier via the APP VIP and then the NAT'd vNIC address of the Edge
    write-host -foregroundcolor "Green" "Creating Web to App Tier rules"
    $WebToAppVIP = get-nsxfirewallsection $horizonFirewallSectionName | New-NsxFirewallRule -Name "$horizonSgName to App VIP" -Source $HorizonSg -Destination $HorizonVIP_IpSet -Service $HttpService -Action $AllowTraffic -AppliedTo $HorizonSg, $AppSg -position bottom
    $ESGToApp = get-NsxFirewallSection $horizonFirewallSectionName | New-NsxFirewallRule -Name "App ESG interface to $AppSgName" -Source $InternalEsg_IpSet -Destination $appSg -service $HttpService -Action $Allowtraffic -AppliedTo $AppSg -position bottom

    #Allows App tier to reach DB Tier directly
    write-host -foregroundcolor "Green" "Creating Db Tier rules"
    $AppToDb = get-nsxfirewallsection $horizonFirewallSectionName | New-NsxFirewallRule -Name "$AppSgName to $DbSgName" -Source $AppSg -Destination $DbSg -Service $MySqlService -Action $AllowTraffic -AppliedTo $AppSg, $DbSG -position bottom

    write-host -foregroundcolor "Green" "Creating deny all applied to $vAppSgName"
    #Default rule that wraps around all VMs within the topolgoy - application specific DENY ALL
    $BooksDenyAll = get-nsxfirewallsection $horizonFirewallSectionName | New-NsxFirewallRule -Name "Deny All Books" -Action $DenyTraffic -AppliedTo $BooksSg -position bottom -EnableLogging -tag "$BooksSG"
    write-host -foregroundcolor "Green" "Books application deployment complete."
}

Write-Host "`n The deployment and configuraiton of NSX is complete `n" -ForegroundColor Green

$vSpherePortGroup = Get-VDPortgroup | Where-Object{$_.Name -like "*$($HorizonLs.vdnId)-$($HorizonLs.Name)"} | Select-Object Name
Write-Host "The Name of the Horizon Management Network is: ($($vSpherePortGroup.Name))" 
$eucConfig.horizonConfig.connectionServers.mgmtPortGroup = $vSpherePortGroup.Name
$eucConfig | ConvertTo-Json -Depth 100 | Set-Content $eucConfigJson

#return $vSpherePortGroup

Disconnect-NsxServer * -Confirm:$false