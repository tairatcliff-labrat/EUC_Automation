<#
========================================================================
 Created on:   05/25/2018
 Created by:   Tai Ratcliff
 Organization: VMware	 
 Filename:     installConnectionServers.ps1
 Example:      installConnectionServers.ps1 -eucConfigJson eucConfigXML.json
========================================================================
#>

param(
    [ValidateScript({Test-Path -Path $_})]
    [String]$eucConfigJson = "$PsScriptRoot\..\..\eucConfig.json"
)

$eucConfig = Get-Content -Path $eucConfigJson | ConvertFrom-Json

$strRunDate = Get-Date

$script:StartTime
$global:strDateStamp = [string]$strRunDate.Year + "" + [string]$strRunDate.Month + "" + [string]$strRunDate.Day + "-" + [string]$strRunDate.Hour + "" + [string]$strRunDate.Minute + "" + [string]$strRunDate.Second
$global:Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

#Clear-Host 
#Write-Host `n `n `n `n `n `n `n 

$mgmtvCenterServer = If($eucConfig.mgmtConfig.mgmtvCenter){$eucConfig.mgmtConfig.mgmtvCenter} Else {throw "Management vCenter Server not set"}
$horizonServiceAccount = If($eucConfig.horizonServiceAccount.Username){$eucConfig.horizonServiceAccount.Username} Else { throw "Horizon service account username not set"}
$horizonServiceAccountPassword = If($eucConfig.horizonServiceAccount.Password){$eucConfig.horizonServiceAccount.Password} Else {throw "Horizon service account password not set"}
$horizonInstallBinary = If($eucConfig.horizonInstallBinary){$eucConfig.horizonInstallBinary} Else {throw "Horizon install binary location not set"}
	If (Test-Path ($horizonInstallBinary)){$horizonBinary = Get-Content -Path $horizonInstallBinary} Else {throw "$horizonInstallBinary does not exist or can not be found"}
$deploymentDestinationDirectory = If($eucConfig.deploymentDestinationDirectory){$eucConfig.deploymentDestinationDirectory} Else {throw "EUC deployment destination directory not set"}
$hznAdminSID = If($eucConfig.horizonServiceAccount.horizonLocalAdminSID){$eucConfig.horizonServiceAccount.horizonLocalAdminSID} Else {throw "Horizon local administrator SID not set"}
$hznRecoveryPassword = If($eucConfig.horizonConfig.connectionServers.horizonRecoveryPassword){$eucConfig.horizonConfig.connectionServers.horizonRecoveryPassword} Else {throw "Horizon recovery password not set"}
$hznRecoveryPasswordHint = If($eucConfig.horizonConfig.connectionServers.horizonRecoveryPasswordHint){$eucConfig.horizonConfig.connectionServers.horizonRecoveryPasswordHint} Else {throw "Horizon recovery password hint not set"}
$horizonDestinationBinary = "$deploymentDestinationDirectory\$($horizonBinary.name)" -replace "(?!^\\)\\{2,}","\"
$csServers = If($eucConfig.horizonConfig.connectionServers.horizonCS){$eucConfig.horizonConfig.connectionServers.horizonCS} Else {throw "Connection Servers are not set"}
$domainName = $eucConfig.horizonConfig.connectionServers.domainName
$horizonConnectionServerURL = If($eucConfig.horizonConfig.connectionServers.horizonConnectionServerURL){$eucConfig.horizonConfig.connectionServers.horizonConnectionServerURL} Else {throw Horizon connection server global URL not set}
$horizonLiceseKey = If($eucConfig.horizonConfig.connectionServers.horizonLicensekey){$eucConfig.horizonConfig.connectionServers.horizonLicensekey} Else {Write-Host "Horizon license key not set. This will apply a trail license" -ForegroundColor Red}
$blockvCenters = If($eucConfig.horizonConfig.blockvcenters.vcName){$eucConfig.horizonConfig.blockvcenters.vcName} Else {Write-Host -foreground Red "Horizon block vCenter servers are not been set"}

$ignoreSSL = $eucConfig.horizonConfig.blockvcenters.ignoreSSLValidation
	[System.Convert]::ToBoolean($ignoreSSL) | Out-Null

$configureEventDB = If($eucConfig.horizonConfig.connectionServers.eventDB.configureEventDB){$eucConfig.horizonConfig.connectionServers.eventDB.configureEventDB} Else {throw "Configure Horizon event DB must be set to either 'true' or 'false'"}
	[System.Convert]::ToBoolean($configureEventDB) | Out-Null
if($configureEventDB){
	$eventDbServer = If($eucConfig.horizonConfig.connectionServers.eventDB.servername){$eucConfig.horizonConfig.connectionServers.eventDB.servername} Else {throw "Event DB server is not set"}
	$eventDbName = If($eucConfig.horizonConfig.connectionServers.eventDB.databasename){$eucConfig.horizonConfig.connectionServers.eventDB.databasename} Else {throw "Event DB database name is not set"}
	$eventDbUser = If($eucConfig.horizonConfig.connectionServers.eventDB.eventDbUser){$eucConfig.horizonConfig.connectionServers.eventDB.eventDbUser} Else {throw "Event DB username is not set"}
	$eventDbPassword= If($eucConfig.horizonConfig.connectionServers.eventDB.eventDbPassword){$eucConfig.horizonConfig.connectionServers.eventDB.eventDbPassword} Else {throw "Event DB user password is not set"}
	$eventDbType=  If($eucConfig.horizonConfig.connectionServers.eventDB.eventDbType){$eucConfig.horizonConfig.connectionServers.eventDB.eventDbType} Else {throw "Event DB type is not set"}
	$eventDbTablePrefix=  If($eucConfig.horizonConfig.connectionServers.eventDB.eventDbTablePrefix){$eucConfig.horizonConfig.connectionServers.eventDB.eventDbTablePrefix} Else {throw "Event DB table prefix is not set"}
	$eventDbPort = If([int]$eucConfig.horizonConfig.connectionServers.eventDB.port){[int]$eucConfig.horizonConfig.connectionServers.eventDB.port} Else {throw "Event DB port is not set"}
	$classifyEventsAsNewForDays = If([int]$eucConfig.horizonConfig.connectionServers.eventDB.classifyEventsAsNewForDays){[int]$eucConfig.horizonConfig.connectionServers.eventDB.classifyEventsAsNewForDays} Else {throw "Event DB classify events as new for days is not set"}
	$showEventsForTime = If($eucConfig.horizonConfig.connectionServers.eventDB.showEventsForTime){$eucConfig.horizonConfig.connectionServers.eventDB.showEventsForTime} Else {throw "Event DB show events for time is not set"}
}

$syslogUNCEnable = If($eucConfig.horizonConfig.connectionServers.syslogserver.SyslogFileData.enabled){$eucConfig.horizonConfig.connectionServers.syslogserver.SyslogFileData.enabled} Else {throw "Syslog file data needs to be set to 'true' or 'false'"}
	[System.Convert]::ToBoolean($syslogUNCEnable) | Out-Null
If($syslogUNCEnable){
	$syslogUNCPath = If($eucConfig.horizonConfig.connectionServers.syslogserver.SyslogFileData.uncPath){$eucConfig.horizonConfig.connectionServers.syslogserver.SyslogFileData.uncPath} Else {throw "Syslog UNC path is not set"}
	$syslogUNCUserName = If($eucConfig.horizonConfig.connectionServers.syslogserver.SyslogFileData.uncUserName){$eucConfig.horizonConfig.connectionServers.syslogserver.SyslogFileData.uncUserName} Else {throw "Syslog UNC username is not set"}
	$sysloguncPassword = If($eucConfig.horizonConfig.connectionServers.syslogserver.SyslogFileData.uncPassword){$eucConfig.horizonConfig.connectionServers.syslogserver.SyslogFileData.uncPassword} Else {throw "Syslog UNC password is not set"}
	$sysloguncDomain = If($eucConfig.horizonConfig.connectionServers.syslogserver.SyslogFileData.uncDomain){$eucConfig.horizonConfig.connectionServers.syslogserver.SyslogFileData.uncDomain} Else {throw "Syslog UNC domain is not set"}
}

$syslogUDPenabled = $eucConfig.horizonConfig.connectionServers.syslogserver.SyslogUDPData.enabled
	[System.Convert]::ToBoolean($syslogUDPenabled) | Out-Null
If(syslogUDPenabled){
	$syslogUDPNetworks = $eucConfig.horizonConfig.connectionServers.syslogserver.SyslogUDPData.networkAddresses
}

$useInstantClones = If($eucConfig.horizonConfig.InstantCloneDomainAdministrator.useInstantClones){$eucConfig.horizonConfig.InstantCloneDomainAdministrator.useInstantClones} Else {throw "Instant Clone needs to be set to either 'true' or 'false'"}
	[System.Convert]::ToBoolean($useInstantClones) | Out-Null
If($useInstantClones){
	$icadminuser= If($eucConfig.horizonConfig.InstantCloneDomainAdministrator.userName){$eucConfig.connectionServers.InstantCloneDomainAdministrator.userName} Else {throw "Instant Clone domain admin username is not set"}
	$icadminpw = If($eucConfig.horizonConfig.InstantCloneDomainAdministrator.password){$eucConfig.connectionServers.InstantCloneDomainAdministrator.password} Else {throw "Instant CLone domain admin password is not set"}
	$icadmindomain = If($eucConfig.horizonConfig.InstantCloneDomainAdministrator.domain){$eucConfig.connectionServers.InstantCloneDomainAdministrator.domain} Else {throw "Instant Clone domain is not set"}
}

#----------------------------------------------------------
# Write the log file
$runDateStamp=(get-date -format "yyyy-MM-d-hh-mm-ss")
$logDirectory = "C:\VMware_EUC_Automation\Logs"

$logFile=$logDirectory + "\hzndeploy-"  + $runDateStamp + ".log"
#----------------------------------------------------------

write-host "Start run at " $strRunDate
$global:Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()


function Get-MapEntry {
  param(
    [Parameter(Mandatory = $true)]
    $Key,
    [Parameter(Mandatory = $true)]
    $Value
  )

  $update = New-Object VMware.Hv.MapEntry
  $update.key = $key
  $update.value = $value
  return $update
}
function addVcenter{
	param(
        [string]$vcName,
        [string]$vcuser,
	    [string]$vcpw,
        [switch]$ignoreSSL
	)
	runLog -functionIn $MyInvocation -runMessage "Getting ready to add vCenter $vcName"
		
	$vcService = New-Object VMware.Hv.VirtualCenterService
	$certService = New-Object VMware.Hv.CertificateService
	$vcSpecHelper = $vcService.getVirtualCenterSpecHelper()

	$vcPassword = New-Object VMware.Hv.SecureString
	$enc = [system.Text.Encoding]::UTF8
	$vcPassword.Utf8String = $enc.GetBytes($vcpw)

	$serverSpec = $vcSpecHelper.getDataObject().serverSpec
	$serverSpec.serverName = $vcName
	$serverSpec.port = 443
	$serverSpec.useSSL = $true
	$serverSpec.userName = $vcuser
	$serverSpec.password = $vcPassword
	$serverSpec.serverType = $certService.getServerSpecHelper().SERVER_TYPE_VIRTUAL_CENTER

	$certData = $certService.Certificate_Validate($ViewAPI, $serverSpec)
	$certificateOverride = New-Object VMware.Hv.CertificateThumbprint
	$certificateOverride.sslCertThumbprint = $certData.thumbprint.sslCertThumbprint
	$certificateOverride.sslCertThumbprintAlgorithm = $certData.thumbprint.sslCertThumbprintAlgorithm

    If(!($ignoreSSL)){
	    $vcSpecHelper.getDataObject().CertificateOverride = $certificateOverride
    }
	
    #setup the storage accelerator
	$storageAccelertorSetup = new-object VMware.Hv.VirtualCenterStorageAcceleratorData
	$storageAccelertorSetup.enabled = $true
	$storageAccelertorSetup.defaultCacheSizeMB = 2048
	
	$vcSpecHelper.getDataObject().storageAcceleratorData =  $storageAccelertorSetup
	
	# Make service call
	$vcId = $vcService.VirtualCenter_Create($ViewAPI, $vcSpecHelper.getDataObject())
}
function checkVMState{

	param(
		[string]$vmToCheck
	)
	
	#check if in inventory
	#check if tools running
	$vmState = get-vm $vmToCheck -ErrorAction 'silentlycontinue'
	if (!$vmState){
		runlog -functionIn $MyInvocation.MyCommand -runMessage "VM $vmToCheck not found in inventory"
		$goodVM = $false
		return $goodVM	
	}
	
	if ($vmState.ExtensionData.Guest.ToolsRunningStatus.toupper() -ne "GUESTTOOLSRUNNING"){
		runlog -functionIn $MyInvocation.MyCommand -runMessage "VM $vmToCheck vmtools not running"
		$goodVM = $false	
		return $goodVM
	} else {
		runlog -functionIn $MyInvocation.MyCommand -runMessage "VM $vmToCheck is a good VM"
		$goodVM = $true
		return $goodVM
	}
}
function addInstantDomainAdmin{
	 param(
		[string]$instCloneAdmin,
		[string]$instClonePW,
		[string]$intCloneAdminDomain
	)

	$updatesMap = New-Object VMware.Hv.MapEntry
		
	# HSB This is needed to creat an array of update maps 
 	$updatesMap = @()
	
	$instCloneAdminService = $ViewAPI.InstantCloneEngineDomainAdministrator	
	
	$adminsercpw = createSecurePassword -pwin $instClonePW
	
	$adDomainService = $ViewAPI.ADDomain
	$domainID = $adDomainService.ADDomain_List().id

	$instCloneAdminBase = New-Object VMware.Hv.InstantCloneEngineDomainAdministratorBase
	$instCloneAdminSpec = New-Object VMware.Hv.InstantCloneEngineDomainAdministratorSpec
	
	$instCloneAdminBase.userName = $instCloneAdmin
	
	$instCloneAdminBase.password = $adminsercpw
	
	$instCloneAdminBase.domain = $domainID
	
	$instCloneAdminSpec.base = $instCloneAdminBase
	$instCloneAdminService.InstantCloneEngineDomainAdministrator_Create($instCloneAdminSpec)
}
function createSecurePassword{
	param(
		[string]$pwin
	)
	$SecPassword = New-Object VMware.Hv.SecureString
	$enc = [system.Text.Encoding]::UTF8
	$SecPassword.Utf8String = $enc.GetBytes($pwin)
	return $SecPassword
}
function addEventDB{
	param(
		[string]$dbServer,
		[string]$dbName,
		[string]$dbType,
		[int]$eventDbPort,
		[string]$dbUserName,
		[string]$dbPW,
		[string]$tablePrefix,
		[string]$showEventsForTime,
		[int]$classifyEventsAsNewForDays = 2
	)

	$dbSecPassword = New-Object VMware.Hv.SecureString
	$enc = [system.Text.Encoding]::UTF8
	$dbSecPassword.Utf8String = $enc.GetBytes($dbPW)
	$updatesMap = New-Object VMware.Hv.MapEntry
		
	# HSB This is needed to creat an array of update maps 
	$updatesMap = @()

	#prefixed with database. or settings. and fixed the case of the keynames. They are case sensitive and all start with lowercase 
	$updatesMap += Get-MapEntry –key 'database.server' –value $dbServer
	$updatesMap += Get-MapEntry -Key 'database.type' -Value "SQLSERVER"
		
	#this field requires an INT.  need to cast
	$updatesMap += Get-MapEntry –key 'database.port' –value $eventDbPort
	$updatesMap += Get-MapEntry –key 'database.name' –value $dbName
	$updatesMap += Get-MapEntry –key 'database.userName' –value $dbUserName
	$updatesMap  += Get-MapEntry –key 'database.password' –value $dbSecPassword
	$updatesMap  += Get-MapEntry –key 'database.tablePrefix' –value $tablePrefix
	$updatesMap += Get-MapEntry -Key 'settings.showEventsForTime' -Value $showEventsForTime
	#this field requies an INT. Need to cast	
	$updatesMap += Get-MapEntry -Key 'settings.classifyEventsAsNewForDays' -Value $classifyEventsAsNewForDays

	# It's not clear in the API docs, but the _this parameter is looking for the API object
	$EventDatabaseService = $ViewAPI.EventDatabase
	#only need updates map.
		
	$EventDatabaseService.EventDatabase_Update($updatesMap)
}
function addSYSLOGFile{
	 param(
		[string]$UNCenabled = $false,
		[string]$uncPath,
		[string]$uncUserName,
		[string]$uncPassword,
		[string]$uncDomain,
		[string]$UDPenabled,
		[string]$UDPnetworkAddresses
	)

	$syslogSecPassword = New-Object VMware.Hv.SecureString
	$enc = [system.Text.Encoding]::UTF8
	$syslogSecPassword.Utf8String = $enc.GetBytes($uncPassword)

	$updatesMap = New-Object VMware.Hv.MapEntry
		
	# HSB This is needed to creat an array of update maps 
	$updatesMap = @()
		
	if ([string]::IsNullOrEmpty($UNCenabled) ){
		[bool]$UNCenabledConfig= $false
	} else {
		[bool]$UNCenabledConfig = [bool]$UNCenabled
	}
	
	$updatesMap += Get-MapEntry –key 'fileData.enabled' –value $UNCenabledConfig	
	$updatesMap += Get-MapEntry –key 'fileData.uncPath' –value $uncPath	
	$updatesMap += Get-MapEntry –key 'fileData.uncUserName' –value $uncUserName
	$updatesMap += Get-MapEntry –key 'fileData.uncPassword' –value $syslogSecPassword
	$updatesMap += Get-MapEntry –key 'fileData.uncDomain' –value $uncDomain
		
	[string[]]$networkAddressArray = @()

	$networkAddressArray	

	if ([string]::IsNullOrEmpty($UDPenabled)){
		[bool]$UDPenabledConfig = $false
	} else {
		[bool]$UDPenabledConfig = [bool]$UDPenabled
	}

	if ([string]::IsNullOrEmpty($UDPnetworkAddresses)){
	$networkAddressArray +=''
	} else {
		$networkAddressArray = $UDPnetworkAddresses.split(" ") | where-object {$_ -ne " "}

	}	

	$updatesMap += Get-MapEntry –key 'udpData.enabled' –value $UDPenabledConfig
	$updatesMap += Get-MapEntry –key 'udpData.networkAddresses' –value $networkAddressArray

	$SyslogService = $ViewAPI.Syslog

	$SyslogService.Syslog_Update($updatesMap)
}
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

<#======================================== 
          SCRIPT STARTS HERE 
==========================================#>

# Connect to Management vCenter Server
if($global:defaultVIServers.Name -notcontains $mgmtvCenterServer){
	Connect-VIServer -Server $mgmtvCenterServer -User $horizonServiceAccount -Password $horizonServiceAccountPassword -Force | Out-Null
}
if($global:defaultVIServers.Name -contains $mgmtvCenterServer){
	Write-Host "Successfully connected to $mgmtvCenterServer" -ForegroundColor Green `n
} Else {
	throw "Unable to connect to vCenter Server"
}

for($i = 0; $i -lt $csServers.count; $i++){ 
	#Skip null or empty properties.
	If ([string]::IsNullOrEmpty($csServers[$i])){Continue}
	If($i -eq 0){
		$csInstallCmd = "$horizonDestinationBinary /s /v""/qn VDM_SERVER_INSTANCE_TYPE=1 VDM_INITIAL_ADMIN_SID=$hznAdminSID VDM_SERVER_RECOVERY_PWD=$hznRecoveryPassword VDM_SERVER_RECOVERY_PWD_REMINDER=$hznRecoveryPasswordHint"""
	} Else {
		$csInstallCmd = "$horizonDestinationBinary /s /v""/qn VDM_SERVER_INSTANCE_TYPE=2 ADAM_PRIMARY_NAME=$csFQDN VDM_INITIAL_ADMIN_SID=$hznAdminSID"""
	}

    If(!(checkVMState -vmToCheck $csServers[$i])){throw "Unable to find " + $csServers[$i] + ". The VM is either not in the inventory or VMTools is not responding"}

	Write-Host "Copying the horizon installation files to " + $csServers[$i] -ForegroundColor Blue
	copy-vmguestfile -LocalToGuest -source $horizonInstallBinary -destination $deploymentDestinationDirectory -Force:$true -vm $csServers[$i] -guestuser $horizonServiceAccount -guestpassword $horizonServiceAccountPassword  -ErrorAction SilentlyContinue
    Invoke-VMScript -ScriptText $csInstallCmd  -VM $csServers[$i] -guestuser $horizonServiceAccount -guestpassword $horizonServiceAccountPassword -ErrorAction Stop -scripttype bat

    $csFQDNReturned = Invoke-VMScript -ScriptText "echo %COMPUTERNAME%.%USERDNSDOMAIN%"  -VM $csServers[$i] -guestuser $horizonServiceAccount -guestpassword $horizonServiceAccountPassword -ErrorAction Stop -scripttype bat
    $csFQDN=[string]$csFQDNReturned.scriptoutput -replace "`r`n", "" 

    #Wait for VMTools to respond
    Write-Host "Waiting for VMTools to respond `n" -ForegroundColor Blue 	
    Start-Sleep -Seconds 120
	
	## Validate the connection server is installed and running by validating the service is running on the destination VM using Get-Service
	#$getServiceCmd = (Get-Service | Where{$_.Name -eq "wsbroker"}).Status
	$checkStatusStatusStartTime = Get-Date
	While(($serviceStatus -ne "Running") -and ($checkStatusStatusStartTime.AddMinutes(5) -gt (Get-Date))){
		$serviceStatusOutput = Invoke-VMScript -ScriptText '(Get-Service | Where{$_.Name -eq "wsbroker"}).Status'  -VM $csServers[$i] -guestuser $horizonServiceAccount -guestpassword $horizonServiceAccountPassword -ErrorAction Stop
	#$serviceStatus = [string]$serviceStatusOutput.scriptoutput -replace "`r`n", ""
	#Check if the Trim() works to do the same as the more complext -replace command... 
	$serviceStatus = [string]$serviceStatusOutput.Trim()
		Write-Host "Waiting for the Connection Server service to start on $csName" -ForegroundColor Yellow
		Start-Sleep 30
	}
}

#need to add some error handling here
If($global:defaultHVServers.Name -notcontains $horizonConnectionServerURL){
	connect-hvserver -server $horizonConnectionServerURL -user $horizonServiceAccount -password $horizonServiceAccountPassword
}
If($global:defaultHVServers.Name -contains $horizonConnectionServerURL){
	Write-Host "Successfully connected to $horizonConnectionServerURL" -ForegroundColor Green `n
} Else {
	throw "Unable to connect to Horizon Connection Server"
}
$ViewAPI = $global:DefaultHVServers.extensiondata


If(!([string]::IsNullOrEmpty($horizonLiceseKey))){
	Write-Host "Applying license key to Horizon: $horizonLicenseKey" -ForegroundColor Green
	$ViewAPI.License.license_set($horizonLiceseKey)
} Else {
	Write-Host "Applied trail licnse to Horizon" -ForegroundColor Green
}

foreach ($blockvCenter in $blockvCenters){
    #Skip null or empty properties.
	If ([string]::IsNullOrEmpty($blockvCenter)){Continue}
	Write-Host "Getting ready to add vCenter $blockvCenter" -ForegroundColor Green
    if($ignoreSSL){
	    addVcenter -vcName $blockvCenter -vcuser $horizonServiceAccount -vcpw $horizonServiceAccountPassword -ignoreSSL
    } else {
        addVcenter -vcName $blockvCenter -vcuser $horizonServiceAccount -vcpw $horizonServiceAccountPassword
    }
}

if($configureEventDB){
	Writ-Host "Adding event database $eventDbName" -ForegroundColor Green

	addEventDB -dbName $eventDbName -eventDbPort $eventDbPort -dbPW $eventDbPassword -dbServer $eventDbServer -dbType $eventDbType -dbUserName $eventDbUser -tablePrefix $eventDbTablePrefix -classifyEventsAsNewForDays $classifyEventsAsNewForDays -showEventsForTime $showEventsForTime 
}

if ($syslogUDPenabled){
	addSYSLOGFile -UNCenabled $syslogUNCEnable -uncUserName $syslogUNCUserName -uncPassword $sysloguncPassword -uncDomain $sysloguncDomain -uncPath $syslogUNCPath -UDPenabled $syslogUDPenabled -UDPnetworkAddresses $syslogUDPNetworks	
}

If($useInstantClones){
	addInstantDomainAdmin -instCloneAdmin $icadminuser -instClonePW $icadminpw -instCloneAdminDomain $icadmindomain
}

Disconnect-VIServer * -Force -Confirm:$false