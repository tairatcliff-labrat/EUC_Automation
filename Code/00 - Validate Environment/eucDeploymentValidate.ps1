<#
========================================================================
 Created on:   05/25/2018
 Created by:   Tai Ratcliff
 Organization: VMware	 
 Filename:     eucDeploymentValidate.ps1
 Example:      eucDeploymentValidate.ps1 -eucConfigJson eucConfigXML.json
========================================================================
#>

param(
    [ValidateScript({Test-Path -Path $_})]
    [String]$eucConfigJson = "$PsScriptRoot\..\..\eucConfig.json"
)

$Global:eucConfig = Get-Content -Path $eucConfigJson | ConvertFrom-Json

If($eucConfig.deployNSX){
        $Global:NsxManagerServer = If($eucConfig.nsxConfig.nsxManagerServer){$eucConfig.nsxConfig.nsxManagerServer} Else {Write-Host "NSX Manager Server not set" -foreground Red}
        $Global:NsxManagerPassword = If($eucConfig.nsxConfig.nsxManagerPassword){$eucConfig.nsxConfig.nsxManagerPassword} Else {Write-Host "NSX Manager Password not set" -foreground Red}
        $Global:MgmtvCenterUserName = If($eucConfig.horizonServiceAccount.Username){$eucConfig.horizonServiceAccount.Username} Else {Write-Host "Management vCenter Username not set" -foreground Red}
        $Global:MgmtvCenterPassword = If($eucConfig.horizonServiceAccount.Password){$eucConfig.horizonServiceAccount.Password} Else {Write-Host "Management vCenter Password not set" -foreground Red}
        $Global:MgmtClusterName = If($eucConfig.horizonConfig.connectionServers.mgmtCluster){$eucConfig.horizonConfig.connectionServers.mgmtCluster} Else {Write-Host "Management vCenter cluster name not set" -foreground Red}
        $Global:MgmtVdsName = If($eucConfig.horizonConfig.connectionServers.mgmtVDS){$eucConfig.horizonConfig.connectionServers.mgmtVDS} Else {Write-Host "Management VDS name not set" -foreground Red}
        $Global:mgmtEdgeClusterName = If($eucConfig.nsxConfig.mgmtEdgeClusterName){$eucConfig.nsxConfig.mgmtEdgeClusterName} Else {Write-Host "Management edge cluster name not set" -foreground Red}
        $Global:mgmtEdgeDatastoreName = If($eucConfig.nsxConfig.mgmtEdgeDatastoreName){$eucConfig.nsxConfig.mgmtEdgeDatastoreName} Else {Write-Host "Management edge datastore name not set" -foreground Red}
        $Global:mgmtNsxUplinkPortGroup01Name = If($eucConfig.nsxConfig.mgmtNsxUplinkPortGroup01Name){$eucConfig.nsxConfig.mgmtNsxUplinkPortGroup01Name} Else {Write-Host "Management NSX uplink 01 port group name not set" -foreground Red}
        $Global:mgmtNsxUplinkPortGroup02Name = If($eucConfig.nsxConfig.mgmtNsxUplinkPortGroup02Name){$eucConfig.nsxConfig.mgmtNsxUplinkPortGroup02Name} Else {Write-Host "Management NSX uplink 02 port group name not set" -foreground Red}
        $Global:mgmtNsxFolderName = If($eucConfig.nsxConfig.mgmtNsxFolderName){$eucConfig.nsxConfig.mgmtNsxFolderName} Else {Write-Host "Management NSX folder name not set" -foreground Red}
        $Global:mgmtDatacenterName = If($eucConfig.mgmtConfig.mgmtDatacenterName){$eucConfig.mgmtConfig.mgmtDatacenterName} Else {Write-Host "Management datacenter name not set" -foreground Red}
        $Global:tor01UplinkProtocolAddress = If($eucConfig.nsxConfig.mgmtTor01UplinkProtocolAddress){$eucConfig.nsxConfig.mgmtTor01UplinkProtocolAddress} Else {Write-Host "Management Top of Rack uplink 01 address not set" -foreground Red}
        $Global:tor02UplinkProtocolAddress = If($eucConfig.nsxConfig.mgmtTor02UplinkProtocolAddress){$eucConfig.nsxConfig.mgmtTor02UplinkProtocolAddress} Else {Write-Host "Management Top of Rack uplink 02 address not set" -foreground Red}
        $Global:Edge01Uplink01PrimaryAddress = If($eucConfig.nsxConfig.mgmtEdge01Uplink01PrimaryAddress){$eucConfig.nsxConfig.mgmtEdge01Uplink01PrimaryAddress} Else {Write-Host "Management edge 01 uplink 01 address not set" -foreground Red}
        $Global:Edge01Uplink02PrimaryAddress = If($eucConfig.nsxConfig.mgmtEdge01Uplink02PrimaryAddress){$eucConfig.nsxConfig.mgmtEdge01Uplink02PrimaryAddress} Else {Write-Host "Management edge 01 uplink 02 address not set" -foreground Red}
        $Global:Edge02Uplink01PrimaryAddress = If($eucConfig.nsxConfig.mgmtEdge02Uplink01PrimaryAddress){$eucConfig.nsxConfig.mgmtEdge02Uplink01PrimaryAddress} Else {Write-Host "Management edge 02 uplink 01 address not set" -foreground Red}
        $Global:Edge02Uplink02PrimaryAddress = If($eucConfig.nsxConfig.mgmtEdge02Uplink02PrimaryAddress){$eucConfig.nsxConfig.mgmtEdge02Uplink02PrimaryAddress} else {Write-Host "Management edge 02 uplink 02 address not set" -foreground Red}
        $Global:bgpPassword = $eucConfig.nsxConfig.bgpPassword
        $Global:uplinkASN01 = If($eucConfig.nsxConfig.mgmtUplinkASN01){$eucConfig.nsxConfig.mgmtUplinkASN01} Else {Write-Host "Management uplink ASN 01 not set" -foreground Red}
        $Global:uplinkASN02 = If($eucConfig.nsxConfig.mgmtUplinkASN02){$eucConfig.nsxConfig.mgmtUplinkASN02} Else {Write-Host "Management uplink ASN 02 not set" -foreground Red}
        $Global:LocalASN = If($eucConfig.nsxConfig.mgmtLocalASN){$eucConfig.nsxConfig.mgmtLocalASN} Else {Write-Host "Management NSX local ASN not set" -foreground Red}
        $Global:AppliancePassword = If($eucConfig.nsxConfig.mgmtEdgePassword){$eucConfig.nsxConfig.mgmtEdgePassword} Else {Write-Host "Management NSX edge applicance password not set" -foreground Red}
        $Global:mgmtTransitLsName = If($eucConfig.nsxConfig.mgmtTransitLsName){$eucConfig.nsxConfig.mgmtTransitLsName} Else {Write-Host "Management NSX transit logical switch name not set" -foreground Red}
        $Global:mgmtEdgeHAPortGroupName = If($eucConfig.nsxConfig.mgmtEdgeHAPortGroupName){$eucConfig.nsxConfig.mgmtEdgeHAPortGroupName} Else {Write-Host "Management edge HA port group not set" -foreground Red}
        $Global:mgmtEUC_MGMT_Network = If($eucConfig.nsxConfig.mgmtEUC_MGMT_Network){$eucConfig.nsxConfig.mgmtEUC_MGMT_Network} Else {Write-Host "EUC management network network name not set" -foreground Red}
        $Global:mgmtEdge01Name = If($eucConfig.nsxConfig.mgmtEdge01Name){$eucConfig.nsxConfig.mgmtEdge01Name} Else {Write-Host "Management edge 01 name not set" -foreground Red}
        $Global:mgmtEdge02Name = If($eucConfig.nsxConfig.mgmtEdge02Name){$eucConfig.nsxConfig.mgmtEdge02Name} Else {Write-Host "Management edge 02 name not set" -foreground Red}
        $Global:mgmtLdrName = If($eucConfig.nsxConfig.mgmtLdrName){$eucConfig.nsxConfig.mgmtLdrName} Else {Write-Host "Management distributed logical router name not set" -foreground Red}
        $Global:mgmtEUCTransportZoneName = If($eucConfig.nsxConfig.mgmtEUCTransportZoneName){$eucConfig.nsxConfig.mgmtEUCTransportZoneName} Else {Write-Host "Management EUC transport zone name not set" -foreground Red}
        $Global:mgmtEdge01InternalPrimaryAddress = If($eucConfig.nsxConfig.mgmtEdge01InternalPrimaryAddress){$eucConfig.nsxConfig.mgmtEdge01InternalPrimaryAddress} Else {Write-Host "Management edge 01 internal primary IP address not set" -foreground Red}
        $Global:mgmtEdge02InternalPrimaryAddress = If($eucConfig.nsxConfig.mgmtEdge02InternalPrimaryAddress){$eucConfig.nsxConfig.mgmtEdge02InternalPrimaryAddress} Else {Write-Host "Management edge 02 internal primary IP address not set" -foreground Red}
        $Global:mgmtLdrUplinkPrimaryAddress = If($eucConfig.nsxConfig.mgmtLdrUplinkPrimaryAddress){$eucConfig.nsxConfig.mgmtLdrUplinkPrimaryAddress} Else {Write-Host "Management distributed logical router uplink primary IP address not set" -foreground Red}
        $Global:mgmtLdrUplinkProtocolAddress = If($eucConfig.nsxConfig.mgmtLdrUplinkProtocolAddress){$eucConfig.nsxConfig.mgmtLdrUplinkProtocolAddress} Else {Write-Host "Management distributed logical router uplink protocol IP address not set" -foreground Red}
        $Global:mgmtLdrEUCMGMTPrimaryAddress = If($eucConfig.nsxConfig.mgmtLdrEUCMGMTPrimaryAddress){$eucConfig.nsxConfig.mgmtLdrEUCMGMTPrimaryAddress} Else {Write-Host "EUC management distributed locical router primary IP address not set" -foreground Red}
        $Global:mgmtDefaultSubnetBits = If($eucConfig.nsxConfig.mgmtDefaultSubnetBits){$eucConfig.nsxConfig.mgmtDefaultSubnetBits} Else {Write-Host "Default management subnet not set" -foreground Red}
        $Global:mgmtDlrHaDatastoreName = If($eucConfig.nsxConfig.mgmtDlrHaDatastoreName){$eucConfig.nsxConfig.mgmtDlrHaDatastoreName} Else {Write-Host "Management distributed logical router HA datastore name not set" -foreground Red}
        $Global:csServers = If($eucConfig.horizonConfig.ConnectionServers.horizonCS){$eucConfig.horizonConfig.ConnectionServers.horizonCS} Else {Write-Host "Connection Servers are not set" -foreground Red}
        Write-Host "`nFinished validating the NSX logical networking configuration `n" -foreground Green

    ## Only validate these settings if deploying NSX Load Balancers
    If($eucConfig.nsxConfig.deployLoadBalancer){
        $Global:horizonLbEdgeName = $eucConfig.nsxConfig.horizonhorizonLbEdgeName
        $Global:horizonLbPrimaryIPAddress = $eucConfig.nsxConfig.horizonhorizonLbPrimaryIPAddress
        $Global:horizonVipIp = $eucConfig.nsxConfig.horizonVipIp
        $Global:horizonLbAlgorith = $eucConfig.nsxConfig.horizonhorizonLbAlgorithrith
        $Global:horizonLbPoolName = $eucConfig.nsxConfig.horizonLbPoolName
        $Global:horizonVipName = $eucConfig.nsxConfig.horizonVipName
        $Global:horizonAppProfileName = $eucConfig.nsxConfig.horizonAppProfileName
        $Global:horizonVipProtocol = $eucConfig.nsxConfig.horizonhorizonVipProtocol
        $Global:horizonHttpsPort = $eucConfig.nsxConfig.horizonhorizonHttpsPort
        $Global:horizonLBMonitorName = $eucConfig.nsxConfig.horizonhorizonLBMonitorName
        Write-Host "`nFinished validating the NSX load balancer configuration `n" -foreground Green
    }

    ## Only validate these settings if configuring NSX micro segmentation
    If($eucConfig.nsxConfig.deployMicroSeg){
        $Global:horizonSgName = $eucConfig.nsxConfig.horizonSgName
        $Global:horizonSgDescription = $eucConfig.nsxConfig.horizonSgDescription
        $Global:horizonStName = $eucConfig.nsxConfig.horizonStName
        $Global:horizonVIP_IpSet_Name = $eucConfig.nsxConfig.horizonVIP_IpSet_Name
        $Global:horizonInternalESG_IpSet_Name = $eucConfig.nsxConfig.horizonhorizonInternalESG_IpSet_Name
        $Global:horizonFirewallSectionName = $eucConfig.nsxConfig.horizonhorizonFirewallSectionName
        Write-Host "`nFinished validating the NSX micro segmentation configuration `n" -foreground Green
    }
    Write-Host "`nFinished validating the NSX configuration `n" -foreground Green
}

If($eucConfig.cloneHorizonVMs){
    $Global:mgmtvCenterServer = If($eucConfig.mgmtConfig.mgmtvCenter){$eucConfig.mgmtConfig.mgmtvCenter} Else {Write-Host -foreground Red "Management vCenter Server not set"}
    $Global:horizonServiceAccount = If($eucConfig.horizonServiceAccount.Username){$eucConfig.horizonServiceAccount.Username} Else { Write-Host -foreground Red "Horizon service account username not set"}
    $Global:horizonServiceAccountPassword = If($eucConfig.horizonServiceAccount.Password){$eucConfig.horizonServiceAccount.Password} Else {Write-Host -foreground Red "Horizon service account password not set"}

    $Global:csServerArray = If($eucConfig.horizonConfig.connectionServers.horizonCS){$eucConfig.horizonConfig.connectionServers.horizonCS} Else {Write-Host -foreground Red "Connection Servers are not set"}

    $Global:folderName = If($eucConfig.horizonConfig.connectionServers.mgmtFolder){$eucConfig.horizonConfig.connectionServers.mgmtFolder} Else {Write-Host -foreground Red "EUC management folder not set"}
    $Global:datacenterName = If($eucConfig.horizonConfig.connectionServers.mgmtDatacenterName){$eucConfig.horizonConfig.connectionServers.mgmtDatacenterName} Else {Write-Host -foreground Red "EUC management datacenter name not set"}

    $Global:subnetMask = If($eucConfig.horizonConfig.connectionServers.subnetMask){$eucConfig.horizonConfig.connectionServers.subnetMask} Else {Write-Host -foreground Red "Horizon Connection Server subnet mast not set"}
    $Global:gateway = If($eucConfig.horizonConfig.connectionServers.gateway){$eucConfig.horizonConfig.connectionServers.gateway} Else {Write-Host -foreground Red "Horizon Connection Server gateway not set"}
    $Global:dnsServer = If($eucConfig.horizonConfig.connectionServers.dnsServerIP){$eucConfig.horizonConfig.connectionServers.dnsServerIP} Else {Write-Host -foreground Red "Horizon Connection Server DNS not set"}
    $Global:orgName = If($eucConfig.horizonConfig.connectionServers.orgName){$eucConfig.horizonConfig.connectionServers.orgName} Else {Write-Host -foreground Red "Horizon Connection Server guest optimization organization name not set"}
    $Global:domainName = If($eucConfig.horizonConfig.connectionServers.domainName){$eucConfig.horizonConfig.connectionServers.domainName} Else {Write-Host -foreground Red "Horizon Connection Server guest optimization domain name not set"}
    $Global:timeZone = If($eucConfig.horizonConfig.connectionServers.timeZone){$eucConfig.horizonConfig.connectionServers.timeZone } Else {Write-Host -foreground Red "Horizon Connection Server guest optimization time zone not set"}
    $Global:domainJoinUser = If($eucConfig.horizonConfig.connectionServers.domainJoinUser){$eucConfig.horizonConfig.connectionServers.domainJoinUser} Else {Write-Host -foreground Red "Horizon Connection Server guest optimization domain join user not set"}
    $Global:domainJoinPass = If($eucConfig.horizonConfig.connectionServers.domainJoinPass){$eucConfig.horizonConfig.connectionServers.domainJoinPass} Else {Write-Host -foreground Red "Horizon Connection Server guest opimization domain join user password not set"}
    $Global:productKey = If($eucConfig.horizonConfig.connectionServers.windowsLicenceKey){$eucConfig.horizonConfig.connectionServers.windowsLicenceKey} Else {Write-Host -foreground Red "Horizon Connection Server guest optimization windows product key not set"}
    $Global:mgmtDatastore = If($eucConfig.horizonConfig.connectionServers.mgmtDatastore){$eucConfig.horizonConfig.connectionServers.mgmtDatastore} Else {Write-Host -foreground Red "Management datastore not set"}
    $Global:hznReferenceVM = If($eucConfig.horizonConfig.connectionServers.hznReferenceVM){$eucConfig.horizonConfig.connectionServers.hznReferenceVM} Else {Write-Host -foreground Red "Horizon reference VM template not set"}
    $Global:diskFormat = If($eucConfig.horizonConfig.connectionServers.diskFormat){$eucConfig.horizonConfig.connectionServers.diskFormat} Else {Write-Host -foreground Red "Horizon Connection Server disk format not set"}
    $Global:mgmtCluster = If($eucConfig.horizonConfig.connectionServers.mgmtCluster){$eucConfig.horizonConfig.connectionServers.mgmtCluster} Else {Write-Host -foreground Red "Management cluster not set"}
    $Global:mgmtPortGroup = If($eucConfig.horizonConfig.connectionServers.mgmtPortGroup){$eucConfig.horizonConfig.connectionServers.mgmtPortGroup} Else {Write-Host -foreground Red "Horizon Connection Server port group not set"}
    $Global:affinityRuleName = If($eucConfig.horizonConfig.connectionServers.affinityRuleName){$eucConfig.horizonConfig.connectionServers.affinityRuleName} Else {Write-Host -foreground Red "Horizon Connection Server anti-affinity rule name is not set"}
    If($eucConfig.horizonConfig.certificateConfig.requestCASignedCertificate){
        $Global:deploymentSourceDirectory = Get-Item -path $eucConfig.deploymentSourceDirectory
        $Global:deploymentDestinationDirectory = If($eucConfig.deploymentDestinationDirectory){$eucConfig.deploymentDestinationDirectory} Else {Write-Host -foreground Red "EUC deployment desitation directory not set"}
        $Global:requestCASignedCertificate = If($eucConfig.horizonConfig.certificateConfig.requestCASignedCertificate){$eucConfig.horizonConfig.certificateConfig.requestCASignedCertificate} Else {Write-Host -foreground Red "The option to request CA Signed Certificates is not set to either 'true' or 'false'"}
        $Global:caName = If($eucConfig.horizonConfig.certificateConfig.caName){$eucConfig.horizonConfig.certificateConfig.caName} Else {Write-Host -foreground Red "CA certificate authority name not set"}
        $Global:country = If($eucConfig.horizonConfig.certificateConfig.country){$eucConfig.horizonConfig.certificateConfig.country} Else {Write-Host -foreground Red "CA certificate country not set"}
        $Global:state = If($eucConfig.horizonConfig.certificateConfig.state){$eucConfig.horizonConfig.certificateConfig.state} Else {Write-Host -foreground Red "CA certificate state not set"}
        $Global:city = If($eucConfig.horizonConfig.certificateConfig.city){$eucConfig.horizonConfig.certificateConfig.city} Else {Write-Host -foreground Red "CA certificate city not set"}
        $Global:organisation = If($eucConfig.horizonConfig.certificateConfig.organisation){$eucConfig.horizonConfig.certificateConfig.organisation} Else {Write-Host -foreground Red "CA certificate organisation not set"}
        $Global:organisationOU = If($eucConfig.horizonConfig.certificateConfig.organisationOU){$eucConfig.horizonConfig.certificateConfig.organisationOU} Else {Write-Host -foreground Red "CA certificate organisation OU not set"}
        $Global:templateName = If($eucConfig.horizonConfig.certificateConfig.templateName){$eucConfig.horizonConfig.certificateConfig.templateName} Else {Write-Host -foreground Red "CA certificate template name not set"}
        $Global:friendlyName = If($eucConfig.horizonConfig.certificateConfig.friendlyName -eq "vdm"){$eucConfig.horizonConfig.certificateConfig.friendlyName} Else {Write-Host -foreground Red "CA certificate friendly name not set to 'vdm'"}
        $Global:commonName = If($eucConfig.horizonConfig.certificateConfig.commonName){$eucConfig.horizonConfig.certificateConfig.commonName} Else {Write-Host -foreground Red "CA certificate common name not set"}
    }
    Write-Host "`nFinished validating the configuration to clone Horizon VMs `n" -foreground Green
}

If($eucConfig.installConnectionServers){
    $Global:mgmtvCenterServer = If($eucConfig.mgmtConfig.mgmtvCenter){$eucConfig.mgmtConfig.mgmtvCenter} Else {Write-Host -foreground Red "Management vCenter Server not set"}
    $Global:horizonServiceAccount = If($eucConfig.horizonServiceAccount.Username){$eucConfig.horizonServiceAccount.Username} Else { Write-Host -foreground Red "Horizon service account username not set"}
    $Global:horizonServiceAccountPassword = If($eucConfig.horizonServiceAccount.Password){$eucConfig.horizonServiceAccount.Password} Else {Write-Host -foreground Red "Horizon service account password not set"}
    $Global:horizonInstallBinary = If($eucConfig.horizonInstallBinary){$eucConfig.horizonInstallBinary} Else {Write-Host -foreground Red "Horizon install binary location not set"}
        Test-Path $horizonInstallBinary | Out-Null
        #{$horizonBinary = Get-Content -Path $horizonInstallBinary} Else {Write-Host -foreground Red "$horizonInstallBinary does not exist or can not be found"}
    $Global:deploymentDestinationDirectory = If($eucConfig.deploymentDestinationDirectory){$eucConfig.deploymentDestinationDirectory} Else {Write-Host -foreground Red "EUC deployment destination directory not set"}
    $Global:hznAdminSID = If($eucConfig.horizonServiceAccount.horizonLocalAdminSID){$eucConfig.horizonServiceAccount.horizonLocalAdminSID} Else {Write-Host -foreground Red "Horizon local administrator SID not set"}
    $Global:hznRecoveryPassword = If($eucConfig.horizonConfig.connectionServers.horizonRecoveryPassword){$eucConfig.horizonConfig.connectionServers.horizonRecoveryPassword} Else {Write-Host -foreground Red "Horizon recovery password not set"}
    $Global:hznRecoveryPasswordHint = If($eucConfig.horizonConfig.connectionServers.horizonRecoveryPasswordHint){$eucConfig.horizonConfig.connectionServers.horizonRecoveryPasswordHint} Else {Write-Host -foreground Red "Horizon recovery password hint not set"}
    $Global:horizonDestinationBinary = "$deploymentDestinationDirectory\$($horizonBinary.name)" -replace "(?!^\\)\\{2,}","\"
    $Global:csServers = If($eucConfig.horizonConfig.connectionServers.horizonCS){$eucConfig.horizonConfig.connectionServers.horizonCS} Else {Write-Host -foreground Red "Connection Servers are not set"}
    $Global:horizonConnectionServerURL = If($eucConfig.horizonConfig.connectionServers.horizonConnectionServerURL){$eucConfig.horizonConfig.connectionServers.horizonConnectionServerURL} Else {throw "Horizon connection server global URL not set"}
    $Global:domainName = $eucConfig.horizonConfig.connectionServers.domainName
    $Global:horizonLiceseKey = If($eucConfig.horizonConfig.connectionServers.horizonLicensekey){$eucConfig.horizonConfig.connectionServers.horizonLicensekey} Else {Write-Host "Horizon license key not set. This will apply a trail license" -ForegroundColor Red}
    $Global:blockvCenters = If($eucConfig.horizonConfig.blockvcenters.vcName){$eucConfig.horizonConfig.blockvcenters.vcName} Else {Write-Host -foreground Red "Horizon block vCenter servers are not been set"}

    if($eucConfig.horizonConfig.connectionServers.eventDB.configureEventDB){
        $eventDbServer = If($eucConfig.horizonConfig.connectionServers.eventDB.servername){$eucConfig.horizonConfig.connectionServers.eventDB.servername} Else {Write-Host -foreground Red "Event DB server is not set"}
        $eventDbName = If($eucConfig.horizonConfig.connectionServers.eventDB.databasename){$eucConfig.horizonConfig.connectionServers.eventDB.databasename} Else {Write-Host -foreground Red "Event DB database name is not set"}
        $eventDbUser = If($eucConfig.horizonConfig.connectionServers.eventDB.eventDbUser){$eucConfig.horizonConfig.connectionServers.eventDB.eventDbUser} Else {Write-Host -foreground Red "Event DB username is not set"}
        $eventDbPassword= If($eucConfig.horizonConfig.connectionServers.eventDB.eventDbPassword){$eucConfig.horizonConfig.connectionServers.eventDB.eventDbPassword} Else {Write-Host -foreground Red "Event DB user password is not set"}
        $eventDbType =  If($eucConfig.horizonConfig.connectionServers.eventDB.eventDbType){$eucConfig.horizonConfig.connectionServers.eventDB.eventDbType} Else {Write-Host -foreground Red "Event DB type is not set"}
        $eventDbTablePrefix=  If($eucConfig.horizonConfig.connectionServers.eventDB.eventDbTablePrefix){$eucConfig.horizonConfig.connectionServers.eventDB.eventDbTablePrefix} Else {Write-Host -foreground Red "Event DB table prefix is not set"}
        $eventDbPort = If([int]$eucConfig.horizonConfig.connectionServers.eventDB.eventDbPort){[int]$eucConfig.horizonConfig.connectionServers.eventDB.eventDbPort} Else {Write-Host -foreground Red "Event DB port is not set"}
        $classifyEventsAsNewForDays = If([int]$eucConfig.horizonConfig.connectionServers.eventDB.classifyEventsAsNewForDays){[int]$eucConfig.horizonConfig.connectionServers.eventDB.classifyEventsAsNewForDays} Else {Write-Host -foreground Red "Event DB classify events as new for days is not set"}
        $showEventsForTime = If($eucConfig.horizonConfig.connectionServers.eventDB.showEventsForTime){$eucConfig.horizonConfig.connectionServers.eventDB.showEventsForTime} Else {Write-Host -foreground Red "Event DB show events for time is not set"}
    }
    If($eucConfig.horizonConfig.connectionServers.syslogserver.SyslogFileData.enabled){
        $Global:syslogUNCPath = If($eucConfig.horizonConfig.connectionServers.syslogserver.SyslogFileData.uncPath){$eucConfig.horizonConfig.connectionServers.syslogserver.SyslogFileData.uncPath} Else {Write-Host -foreground Red "Syslog UNC path is not set"}
        $Global:syslogUNCUserName = If($eucConfig.horizonConfig.connectionServers.syslogserver.SyslogFileData.uncUserName){$eucConfig.horizonConfig.connectionServers.syslogserver.SyslogFileData.uncUserName} Else {Write-Host -foreground Red "Syslog UNC username is not set"}
        $Global:sysloguncPassword = If($eucConfig.horizonConfig.connectionServers.syslogserver.SyslogFileData.uncPassword){$eucConfig.horizonConfig.connectionServers.syslogserver.SyslogFileData.uncPassword} Else {Write-Host -foreground Red "Syslog UNC password is not set"}
        $Global:sysloguncDomain = If($eucConfig.horizonConfig.connectionServers.syslogserver.SyslogFileData.uncDomain){$eucConfig.horizonConfig.connectionServers.syslogserver.SyslogFileData.uncDomain} Else {Write-Host -foreground Red "Syslog UNC domain is not set"}
    }
    If($eucConfig.horizonConfig.connectionServers.syslogserver.SyslogUDPData.enabled){
        $Global:syslogUDPNetworks = $eucConfig.horizonConfig.connectionServers.syslogserver.SyslogUDPData.networkAddresses
    }
    If($eucConfig.horizonConfig.InstantCloneDomainAdministrator.useInstantClones){
        $Global:icadminuser = If($eucConfig.horizonConfig.InstantCloneDomainAdministrator.userName){$eucConfig.horizonConfig.InstantCloneDomainAdministrator.userName} Else {Write-Host -foreground Red "Instant Clone domain admin username is not set"}
        $Global:icadminpw = If($eucConfig.horizonConfig.InstantCloneDomainAdministrator.password){$eucConfig.horizonConfig.InstantCloneDomainAdministrator.password} Else {Write-Host -foreground Red "Instant CLone domain admin password is not set"}
        $Global:icadmindomain = If($eucConfig.horizonConfig.InstantCloneDomainAdministrator.domain){$eucConfig.horizonConfig.InstantCloneDomainAdministrator.domain} Else {Write-Host -foreground Red "Instant Clone domain is not set"}
    }
    Write-Host "`nFinished validating the configuration Horizon Connection Server install `n" -foreground Green
}

If($eucConfig.buildNSXDesktopNetworks){
    $Global:DesktopNsxManagerServer = If($eucConfig.nsxConfig.desktopNsxManagerServer){$eucConfig.nsxConfig.desktopNsxManagerServer} Else {Write-Host -foreground Red "Desktop NSX Manager is not set"}
    $Global:DesktopNsxAdminPassword = If($eucConfig.nsxConfig.desktopNsxAdminPassword){$eucConfig.nsxConfig.desktopNsxAdminPassword} Else {Write-Host -foreground Red "Desktop NSX Manager password is not set"}
    $Global:DesktopvCenterUserName = If($eucConfig.nsxConfig.desktopvCenterUserName){$eucConfig.nsxConfig.desktopvCenterUserName} Else {Write-Host -foreground Red "Desktop vCenter username is not set"}
    $Global:DesktopvCenterPassword = If($eucConfig.nsxConfig.desktopvCenterPassword){$eucConfig.nsxConfig.desktopvCenterPassword} Else {Write-Host -foreground Red "Desktop vCenter password is not set"}
    $Global:DesktopLsName = If($eucConfig.nsxConfig.desktopLsName){$eucConfig.nsxConfig.desktopLsName} Else {Write-Host -foreground Red "Desktop logical switch name is not set"}
    $Global:RDSLsName = If($eucConfig.nsxConfig.RdsLsName){$eucConfig.nsxConfig.RdsLsName} Else {Write-Host -foreground Red "RDS logical switch name is not set"}
    $Global:DesktopLdrName = If($eucConfig.nsxConfig.desktopLdrName){$eucConfig.nsxConfig.desktopLdrName} Else {Write-Host -foreground Red "Desktop logical router name is not set"}
    $Global:DesktopTransportZoneName = If($eucConfig.nsxConfig.desktopTransportZoneName){$eucConfig.nsxConfig.desktopTransportZoneName} Else {Write-Host -foreground Red "Desktop transport zone name is not set"}
    $Global:dnsServer = If($eucConfig.horizonConfig.connectionServers.dnsServerIP){$eucConfig.horizonConfig.connectionServers.dnsServerIP} Else {Write-Host -foreground Red "DNS server not set"}
    $Global:DesktopNetwork = If($eucConfig.nsxConfig.desktopNetwork){$eucConfig.nsxConfig.desktopNetwork} Else {Write-Host -foreground Red "Desktop network is not set"}
    $Global:DesktopNetworkPrimaryAddress = If($eucConfig.nsxConfig.desktopNetworkPrimaryAddress){$eucConfig.nsxConfig.desktopNetworkPrimaryAddress} Else {Write-Host -foreground Red "Desktop network primary address is not set"}
    $Global:desktopSubnetMask = If($eucConfig.nsxConfig.desktopSubnetMask){$eucConfig.nsxConfig.desktopSubnetMask} Else {Write-Host -foreground Red "Desktop subnet mask name is not set"}
    $Global:RdsNetwork = If($eucConfig.nsxConfig.desktopRdsNetwork){$eucConfig.nsxConfig.desktopRdsNetwork} Else {Write-Host -foreground Red "RDS network is not set"}
    $Global:RdsNetworkPrimaryAddress = If($eucConfig.nsxConfig.desktopRdsNetworkPrimaryAddress){$eucConfig.nsxConfig.desktopRdsNetworkPrimaryAddress} Else {Write-Host -foreground Red "RDS network primary address is not set"}
    $Global:RdsSubnetMask = If($eucConfig.nsxConfig.desktopRdsSubnetMask){$eucConfig.nsxConfig.desktopRdsSubnetMask} Else {Write-Host -foreground Red "RDS subnet mask is not set"}
    $Global:desktopEdge01Name = If($eucConfig.nsxConfig.desktopEdge01Name){$eucConfig.nsxConfig.desktopEdge01Name} Else {Write-Host -foreground Red "Desktop edge name is not set"}
    $Global:desktopEdge01TransitIP = If($eucConfig.nsxConfig.desktopEdge01TransitIP){$eucConfig.nsxConfig.desktopEdge01TransitIP} Else {Write-Host -foreground Red "Desktop edge transip IP is not set"}
    If(! $eucConfig.nsxConfig.useEdgeDHCPServer){
        $Global:dhcpServerAddress = If($eucConfig.nsxConfig.desktopDhcpServerAddress){$eucConfig.nsxConfig.desktopDhcpServerAddress} Else {Write-Host -foreground Red "DHCP server is not set"}
    }
    If($eucConfig.nsxConfig.deployMicroSeg){
        ## Security Groups
        $Global:desktopSgName = If($eucConfig.nsxConfig.desktopSgName){$eucConfig.nsxConfig.desktopSgName} Else {Write-Host -foreground Red "Desktop security group is not set"}
        $Global:desktopSgDescription = If($eucConfig.nsxConfig.desktopSgDescription){$eucConfig.nsxConfig.desktopSgDescription} Else {Write-Host -foreground Red "Desktop security group description is not set"}
        ## Security Tags
        $Global:desktopStName = If($eucConfig.nsxConfig.desktopStName){$eucConfig.nsxConfig.desktopStName} Else {Write-Host -foreground Red "Desktop security tag is not set"}
        ##DFW
        $Global:desktopFirewallSectionName = If($eucConfig.nsxConfig.desktopFirewallSectionName){$eucConfig.nsxConfig.desktopFirewallSectionName} Else {Write-Host -foreground Red "Desktop firewall section name is not set"}
    }
    Write-Host "`nFinished validating the configuration to build NSX desktop networks `n" -foreground Green
}

If($eucConfig.buildDesktopPools){
    foreach ($newPool in $eucConfig.horizonConfig.pool.desktopPool) {
        $Global:poolType = If([string]$newPool.PoolType.toupper()){[string]$newPool.PoolType.toupper()} Else {Write-Host -foreground Red "Pool type not set"}
        $Global:folderName = If($newPool.VmFolder){$newPool.VmFolder} Else {Write-Host -foreground Red "Pool folder name not set"}
        $Global:masterVM = If($newPool.ParentVM){$newPool.ParentVM} Else {Write-Host -foreground Red "Pool master VM not set"}
        Write-Host "Validating a new $poolType pool named $($newPool.PoolName)"
        If($poolType -eq "INSTANTCLONE"){
            $Global:PoolName = $newPool.PoolName  
            $Global:PoolDisplayName = $newPool.PoolDisplayName  
            $Global:Description = $newPool.Description  
            $Global:UserAssignment = $newPool.UserAssignment  
            $Global:ParentVM = $newPool.ParentVM  
            $Global:SnapshotVM = $newPool.SnapshotVM  
            $Global:VmFolder = $newPool.VmFolder  
            $Global:HostOrCluster = $newPool.HostOrCluster  
            $Global:ResourcePool = $newPool.ResourcePool  
            $Global:NamingMethod = $newPool.NamingMethod  
            $Global:Datastores = $newPool.Datastores   
            $Global:NamingPattern = $newPool.NamingPattern  
            $Global:NetBiosName = $newPool.NetBiosName  
            $Global:DomainAdmin = $newPool.DomainAdmin  
            $Global:vCenter = $newPool.vCenter  
            $Global:MinimumCount = $newPool.MinimumCount  
            $Global:MaximumCount = $newPool.MaximumCount 
        }
        If($poolType -eq "FULLCLONE"){ 
            #runlog -functionIn $MyInvocation.MyCommand -runMessage $message
            $Global:PoolName = $newPool.PoolName   
            $Global:PoolDisplayName = $newPool.PoolDisplayName   
            $Global:Description = $newPool.Description  
            $Global:UserAssignment = $newPool.UserAssignment  
            $Global:VmFolder = $newPool.VmFolder  
            $Global:HostOrCluster = $newPool.HostOrCluster  
            $Global:ResourcePool = $newPool.ResourcePool  
            $Global:NamingMethod = $newPool.NamingMethod  
            $Global:Datastores = $newPool.Datastores   
            $Global:NamingPattern = $newPool.NamingPattern  
            $Global:NetBiosName = $newPool.NetBiosName  
            $Global:vCenter = $newPool.vCenter   
            $Global:Template = $newPool.Template 
            $Global:SysPrepName = $newPool.SysPrepName  
            $Global:CustType = $newPool.CustType
        }
    }	
    Write-Host "`nFinished validating the configuration of the desktop pools `n" -foreground Green
}

