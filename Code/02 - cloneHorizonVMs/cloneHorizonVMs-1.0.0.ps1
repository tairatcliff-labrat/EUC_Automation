<#
========================================================================
 Created on:   05/25/2018
 Created by:   Tai Ratcliff
 Organization: VMware	 
 Filename:     cloneHorizonVMs.ps1
 Example:      cloneHorizonVMs.ps1 -eucConfigJson eucConfigXML.json
========================================================================
#>

param(
    [ValidateScript({Test-Path -Path $_})]
    [String]$eucConfigJson = "$PsScriptRoot\..\..\eucConfig.json",
    [Switch]$rollback
)

$eucConfig = Get-Content -Path $eucConfigJson | ConvertFrom-Json

#Clear-Host 

#Write-Host `n `n `n `n `n `n `n

$mgmtvCenterServer = If($eucConfig.mgmtConfig.mgmtvCenter){$eucConfig.mgmtConfig.mgmtvCenter} Else {throw "Management vCenter Server not set"}
$horizonServiceAccount = If($eucConfig.horizonServiceAccount.Username){$eucConfig.horizonServiceAccount.Username} Else { throw "Horizon service account username not set"}
$horizonServiceAccountPassword = If($eucConfig.horizonServiceAccount.Password){$eucConfig.horizonServiceAccount.Password} Else {throw "Horizon service account password not set"}

$csServerArray = If($eucConfig.horizonConfig.connectionServers.horizonCS){$eucConfig.horizonConfig.connectionServers.horizonCS} Else {throw "Connection Servers are not set"}

$folderName = If($eucConfig.horizonConfig.connectionServers.mgmtFolder){$eucConfig.horizonConfig.connectionServers.mgmtFolder} Else {throw "EUC management folder not set"}
$datacenterName = If($eucConfig.horizonConfig.connectionServers.mgmtDatacenterName){$eucConfig.horizonConfig.connectionServers.mgmtDatacenterName} Else {throw "EUC management datacenter name not set"}

$subnetMask = If($eucConfig.horizonConfig.connectionServers.subnetMask){$eucConfig.horizonConfig.connectionServers.subnetMask} Else {throw "Horizon Connection Server subnet mast not set"}
$gateway = If($eucConfig.horizonConfig.connectionServers.gateway){$eucConfig.horizonConfig.connectionServers.gateway} Else {throw "Horizon Connection Server gateway not set"}
$dnsServer = If($eucConfig.horizonConfig.connectionServers.dnsServerIP){$eucConfig.horizonConfig.connectionServers.dnsServerIP} Else {throw "Horizon Connection Server DNS not set"}
$orgName = If($eucConfig.horizonConfig.connectionServers.orgName){$eucConfig.horizonConfig.connectionServers.orgName} Else {throw "Horizon Connection Server guest optimization organization name not set"}
$domainName = If($eucConfig.horizonConfig.connectionServers.domainName){$eucConfig.horizonConfig.connectionServers.domainName} Else {throw "Horizon Connection Server guest optimization domain name not set"}
$timeZone = If($eucConfig.horizonConfig.connectionServers.timeZone){$eucConfig.horizonConfig.connectionServers.timeZone } Else {throw "Horizon Connection Server guest optimization time zone not set"}
$domainJoinUser = If($eucConfig.horizonConfig.connectionServers.domainJoinUser){$eucConfig.horizonConfig.connectionServers.domainJoinUser} Else {throw "Horizon Connection Server guest optimization domain join user not set"}
$domainJoinPass = If($eucConfig.horizonConfig.connectionServers.domainJoinPass){$eucConfig.horizonConfig.connectionServers.domainJoinPass} Else {throw "Horizon Connection Server guest opimization domain join user password not set"}
$productKey = If($eucConfig.horizonConfig.connectionServers.windowsLicenceKey){$eucConfig.horizonConfig.connectionServers.windowsLicenceKey} Else {throw "Horizon Connection Server guest optimization windows product key not set"}
$mgmtDatastore = If($eucConfig.horizonConfig.connectionServers.mgmtDatastore){$eucConfig.horizonConfig.connectionServers.mgmtDatastore} Else {throw "Management datastore not set"}
$hznReferenceVM = If($eucConfig.horizonConfig.connectionServers.hznReferenceVM){$eucConfig.horizonConfig.connectionServers.hznReferenceVM} Else {throw "Horizon reference VM template not set"}
$diskFormat = If($eucConfig.horizonConfig.connectionServers.diskFormat){$eucConfig.horizonConfig.connectionServers.diskFormat} Else {throw "Horizon Connection Server disk format not set"}
$mgmtCluster = If($eucConfig.horizonConfig.connectionServers.mgmtCluster){$eucConfig.horizonConfig.connectionServers.mgmtCluster} Else {throw "Management cluster not set"}
$mgmtPortGroup = If($eucConfig.horizonConfig.connectionServers.mgmtPortGroup){$eucConfig.horizonConfig.connectionServers.mgmtPortGroup} Else {throw "Horizon Connection Server port group not set"}
$affinityRuleName = If($eucConfig.horizonConfig.connectionServers.affinityRuleName){$eucConfig.horizonConfig.connectionServers.affinityRuleName} Else {throw "Horizon Connection Server anti-affinity rule name is not set"}
[bool]$deployLinkedClones = $eucConfig.horizonConfig.connectionServers.deployLinkedClones
[bool]$requestCASignedCertificate =$eucConfig.horizonConfig.certificateConfig.requestCASignedCertificate

function Start-Sleep($seconds) {
    $doneDT = (Get-Date).AddSeconds($seconds)
    while($doneDT -gt (Get-Date)) {
        $secondsLeft = $doneDT.Subtract((Get-Date)).TotalSeconds
        $percent = ($seconds - $secondsLeft) / $seconds * 100
        Write-Progress -Activity "Sleeping" -Status "Sleeping..." -SecondsRemaining $secondsLeft -PercentComplete $percent
        [System.Threading.Thread]::Sleep(500)
    }
    Write-Progress -Activity "Sleeping" -Status "Sleeping..." -SecondsRemaining 0 -Completed
}

# Connect to Management vCenter Server
if($global:defaultVIServers.Name -notcontains $mgmtvCenterServer){
	Connect-VIServer -Server $mgmtvCenterServer -User $horizonServiceAccount -Password $horizonServiceAccountPassword -Force | Out-Null
}
if($global:defaultVIServers.Name -contains $mgmtvCenterServer){
	Write-Host "Successfully connected to $mgmtvCenterServer" -ForegroundColor Green `n
} Else {
	throw "Unable to connect to vCenter Server"
}

If($rollback){
    for($i = 0; $i -lt $csServerArray.count; $i++){
        $csName = $csServerArray[$i].Name
        If (Get-VM $csName){
            Stop-VM $csName -Confirm:$false | Out-Null
            Remove-VM $csName -DeletePermanently -Confirm:$false | Out-Null
        }
    }
    If (Get-Folder $folderName){
        Remove-Folder $folderName -DeletePermanently -Confirm:$false | Out-Null
    }
    Write-Host "Rolled back Horizon VM Clones`n" -ForegroundColor Green
    Exit
}

# Create a folder for the EUC Management VMs
if(get-Folder -Name $folderName -ErrorAction Ignore){
    Write-Host "Found an existing $foldername VM Folder in vCenter. This is where the Connection Servers will be deployed." -BackgroundColor Yellow -ForegroundColor Black `n
} Else {
    Write-Host "The $foldername VM folder does not exist, creating a new folder" -BackgroundColor Yellow -ForegroundColor Black `n
    (Get-View (Get-View -viewtype datacenter -filter @{"name"="$datacenterName"}).vmfolder).CreateFolder("$folderName") | Out-Null
}


# Clone new Connection Servers
$vmObjectArray = @()
for($i = 0; $i -lt $csServerArray.count; $i++){ 
    #Skip null or empty properties.
    If ([string]::IsNullOrEmpty($csServerArray[$i])){Continue}
    # Guest Customization
    $csName = If($csServerArray[$i].Name){$csServerArray[$i].Name} Else {throw "Horizon Connection Server $i name not set"}
    $ipAddress = If($csServerArray[$i].IP){$csServerArray[$i].IP} Else {throw "Horizon Connection Server $i IP not set"}
    $osCustomizationSpecName = $csName + "-CustomizationSpec"
    
    Write-Host "Now provisioning $csName" -BackgroundColor Blue -ForegroundColor Black `n
    
    # Check if VM already exists in vCenter. If it does, skip to the next VM
    If(Get-VM -Name $csName -ErrorAction Ignore){
        Write-Host "$csName already exists. Moving on to next VM" -ForegroundColor Yellow `n
        Continue
    }

    # If a Guest Customization with the same name already exists then we will remove it. This will make sure that we get the correct settings applied to the VM
    If(Get-OSCustomizationSpec -Name $osCustomizationSpecName -ErrorAction Ignore){
        Remove-OSCustomizationSpec -OSCustomizationSpec $osCustomizationSpecName -Confirm:$false
    }
    
    # Create a new Guest Customization for each VM so that we can configure each OS with the correct details like a static IP    
    New-OSCustomizationSpec -Name $osCustomizationSpecName -Type NonPersistent -OrgName $orgName -OSType Windows -ChangeSid -DnsServer $dnsServer -DnsSuffix $domainName -AdminPassword $horizonServiceAccountPassword -TimeZone $timeZone -Domain $domainName -DomainUsername $domainJoinUser -DomainPassword $domainJoinPass -ProductKey $productKey -NamingScheme fixed -NamingPrefix $csName -LicenseMode Perserver -LicenseMaxConnections 5 -FullName administraton -Server $mgmtvCenterServer | Out-Null
    $osCustomization = Get-OSCustomizationSpec -Name $osCustomizationSpecName | Get-OSCustomizationNicMapping | Set-OSCustomizationNicMapping -IpMode UseStaticIP -IpAddress $ipAddress -SubnetMask $subnetMask -DefaultGateway $gateway -Dns $dnsServer
    If(Get-OSCustomizationSpec -Name $osCustomizationSpecName -ErrorAction Ignore){
        Write-Host "$osCustomizationSpecName profile has been created for $csName" -ForegroundColor Green `n
    } Else {
        Write-Host "$osCustomizationSpecName failed to create for $csName" -ForegroundColor Red `n
    }

    # For testing purposes Linked Clones can be used. For Production full clones must be used. 
    If($deployLinkedClones){
        Write-Host "Deploying $csName as a Linked Clone VM"
        $referenceSnapshot = If($eucConfig.horizonConfig.connectionServers.referenceSnapshot){$eucConfig.horizonConfig.connectionServers.referenceSnapshot} Else {throw "The linked clone reference snapshot name is not set or not available"}
        New-VM -LinkedClone -ReferenceSnapshot $referenceSnapshot -Name $csName -ResourcePool $mgmtCluster -Location $folderName -Datastore $mgmtDatastore -OSCustomizationSpec $osCustomizationSpecName -DiskStorageFormat $diskFormat -Server $mgmtvCenterServer -VM $hznReferenceVM -ErrorAction Stop | Out-Null
        If(Get-VM -Name $csName -ErrorAction Ignore){
            Write-Host "$csName has been provisioned as a Linked Clone VM" -ForegroundColor Green `n
        }
    } Else {
        Write-Host "Deploying $csName as a full clone VM" -ForegroundColor Green `n
        New-VM -Name $csName -Datastore $mgmtDatastore -DiskStorageFormat $diskFormat -OSCustomizationSpec $osCustomizationSpecName -Location $folderName -Server $mgmtvCenterServer -VM $hznReferenceVM -ResourcePool $mgmtCluster | Out-Null
        If(Get-VM -Name $csName -ErrorAction Ignore){
            Write-Host "$csName has been provisioned as a Full Clone VM" -ForegroundColor Green `n
        }
    }

    # Power on the VMs after they are cloned so that the Guest Customizations can be applied
    Start-VM -VM $csName -Confirm:$false | Out-Null
    Write-Host "Powering on $csName VM" -ForegroundColor Yellow `n

    #Make sure the new server is provisioned to the correct network/portgroup and set to "Connected"
    Get-VM $csName | Get-NetworkAdapter | Set-NetworkAdapter -Portgroup $mgmtPortGroup -Confirm:$false | Out-Null
    Get-VM $csName | Get-NetworkAdapter | Set-NetworkAdapter -Connected:$true -Confirm:$false | Out-Null

    # Adding each VM to an array of VM Objects that can be used for bulk modifications.
    If(Get-VM -Name $csName){
        $vmObjectArray += (Get-VM -Name $csName)
    } Else {
        throw "$csName failed to be created"
    }
}

# Wait for a while to ensre the OS Guest Customization is compute and VMTools has started working before trying to execute the in-guest tasks
Write-Host "Pausing the script while we wait until the VMs are ready to execute in-guest operations." -ForegroundColor Yellow
Write-Host "This will take up to 5 minutes for Guest Opimization to complete and VMTools is ready.  " -ForegroundColor Yellow `n
Start-Sleep -Seconds (60*5)

# Set up a DRS anti-affinity rule to keep the Connection Servers running on separate hosts
if(!(Get-DrsRule -Cluster $mgmtCluster -Name $affinityRuleName -ErrorAction Ignore)){
    If($vmObjectArray){ 
        New-DrsRule -Name $affinityRuleName -Cluster $mgmtCluster -VM $vmObjectArray -KeepTogether $false -Enabled $true | Out-Null
    }
    if(Get-DrsRule -Cluster $mgmtCluster -Name $affinityRuleName -ErrorAction Ignore){
        Write-Host "Created a DRS anti-affinity rule for the Connection Servers: $affinityRuleName" -ForegroundColor Green `n
    }
}

If($requestCASignedCertificate){   
    # Apply CA Signed Certificates to each of the Connection Server VMs
    $deploymentSourceDirectory = Get-Item -path $eucConfig.deploymentSourceDirectory
    $deploymentDestinationDirectory = If($eucConfig.deploymentDestinationDirectory){$eucConfig.deploymentDestinationDirectory} Else {throw "EUC deployment desitation directory not set"}
    $caName = If($eucConfig.horizonConfig.certificateConfig.caName){$eucConfig.certificateConfig.caName} Else {throw "CA certificate authority name not set"}
    $country = If($eucConfig.horizonConfig.certificateConfig.country){$eucConfig.certificateConfig.country} Else {throw "CA certificate country not set"}
    $state = If($eucConfig.horizonConfig.certificateConfig.state){$eucConfig.certificateConfig.state} Else {throw "CA certificate state not set"}
    $city = If($eucConfig.horizonConfig.certificateConfig.city){$eucConfig.certificateConfig.city} Else {throw "CA certificate city not set"}
    $organisation = If($eucConfig.horizonConfig.certificateConfig.organisation){$eucConfig.certificateConfig.organisation} Else {throw "CA certificate organisation not set"}
    $organisationOU = If($eucConfig.horizonConfig.certificateConfig.organisationOU){$eucConfig.certificateConfig.organisationOU} Else {throw "CA certificate organisation OU not set"}
    $templateName = If($eucConfig.horizonConfig.certificateConfig.templateName){$eucConfig.certificateConfig.templateName} Else {throw "CA certificate template name not set"}
    $friendlyName = If($eucConfig.horizonConfig.certificateConfig.friendlyName -eq "vdm"){$eucConfig.certificateConfig.friendlyName} Else {throw "CA certificate friendly name not set to 'vdm'"}
	$commonName = If($eucConfig.horizonConfig.certificateConfig.commonName){$eucConfig.certificateConfig.commonName} Else {throw "CA certificate common name not set"}
	
	$createDestinationDirectoryCMD = "If(!(Test-Path -Path $deploymentDestinationDirectory)){New-Item -Path $deploymentDestinationDirectory -ItemType Directory | Out-Null}"

    for($i = 0; $i -lt $csServerArray.count; $i++){
        $csName = $csServerArray[$i].Name
        $fqdn = "$csName.$domainName"
        $certInfSourceFile = "$deploymentSourceDirectory\$csName.inf" -replace "(?!^\\)\\{2,}","\"
        $certInfDestinationFile = "$deploymentDestinationDirectory\$csName.inf" -replace "(?!^\\)\\{2,}","\"
        $certReqDestinationFile = "$deploymentDestinationDirectory\$csName.req" -replace "(?!^\\)\\{2,}","\"
        $certDestinationFile = "$deploymentDestinationDirectory\$csName.cer" -replace "(?!^\\)\\{2,}","\"

        # Even after waiting 5 minutes, VMTools may still not be available. Continue to wait for up to another 5 minutes before proceeding.
        $ToolsRunningStopWatch = [System.Diagnostics.Stopwatch]::StartNew()
        #Define the total time to wait for a response
        $ToolsRunningTimeOut = New-TimeSpan -Minutes 5
        While((Get-VM $csName).ExtensionData.Guest.ToolsRunningStatus.toupper() -ne "GUESTTOOLSRUNNING" -and ($ToolsRunningStopWatch.Elapsed -le $ToolsRunningTimeOut)){
            Write-Host "Still waiting for VMTools to respond on $csName. This will time-out after 5 minutes" -ForegroundColor Yellow
            Start-Sleep -Seconds 30
        }
        
$certReqInf = @"
[NewRequest]
Subject = "CN=$commonName, OU=$organisationOU, O=$organisation, L=$city, S=$state, C=$country"
MachineKeySet = TRUE
KeyLength = 2048
KeySpec=1
Exportable = TRUE
RequestType = PKCS10
FriendlyName = $friendlyName
SMIME = False
PrivateKeyArchive = FALSE
UserProtected = FALSE
UseExistingKeySet = FALSE
ProviderType = 12
KeyUsage = 0xa0
Hashalgorithm = sha256

[EnhancedKeyUsageExtension]
OID=1.3.6.1.5.5.7.3.1 ; this is for Server Authentication

[RequestAttributes]
CertificateTemplate = "$templateName"

[Extensions]
2.5.29.17 = "{text}"
_continue_ = "dns=$fqdn&"
"@      

            Write-Host "Copying certificate configuration scripts to $csName" -ForegroundColor Yellow `n
            # Check the destination directory exists on the VM and if not, create it.
            Invoke-VMScript -ScriptText $createDestinationDirectoryCMD -VM $csName -guestuser $horizonServiceAccount -guestpassword $horizonServiceAccountPassword -ErrorAction Stop
            # Create the certificate .inf file and copy it to the designation VM.
            Set-Content -Path $certInfSourceFile -Value $certReqInf
            Copy-VMGuestfile -LocalToGuest -source "$certInfSourceFile" -destination $deploymentDestinationDirectory -Force:$true  -vm $csName -guestuser $horizonServiceAccount -guestpassword $horizonServiceAccountPassword  -ErrorAction SilentlyContinue
            If(Test-Path "$certInfSourceFile"){Remove-Item -Path "$certInfSourceFile"}

$certReqScript = @"
Invoke-Expression -Command "certreq -new '$certInfDestinationFile' '$certReqDestinationFile'"
Invoke-Expression -Command "certreq -adminforcemachine -submit -config $caName '$certReqDestinationFile' '$certDestinationFile'"
Invoke-Expression -Command "certreq -accept '$certDestinationFile'"
"@
						
            Write-Host "Requesting a new certificate for $csName" -ForegroundColor Yellow `n
            # Use VMTools to execute the certificate request powershell script within the guest OS on the destination server
			Invoke-VMScript -ScriptText $certreqScript -VM $csName -guestuser $horizonServiceAccount -guestpassword $horizonServiceAccountPassword -ErrorAction Stop
            
            # Use VMTools to clean up all of the deployment files from the destination server, without deleting the deployment folder.
            $removeGuestFiles = "Get-ChildItem -Path '$deploymentDestinationDirectory' -Include * -File -Recurse | foreach {`$_.Delete()}"
            Write-Host "Removing left over deployment files from $csName" -ForegroundColor Yellow `n
            Write-Host "$removeGuestFiles `n"
            Invoke-VMScript -ScriptText $removeGuestFiles -VM $csName -guestuser $horizonServiceAccount -guestpassword $horizonServiceAccountPassword -ErrorAction Stop
    }
}
Write-Host "Script Completed" -ForegroundColor Green `n

Disconnect-VIServer * -Force -Confirm:$false