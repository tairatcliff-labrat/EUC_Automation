<#
========================================================================
 Created on:   05/25/2018
 Created by:   Tai Ratcliff
 Organization: VMware	 
 Filename:     buildDesktopPools.ps1
 Example:      buildDesktopPools.ps1 -eucConfigJson eucConfigXML.json
========================================================================
#>

param(
    [ValidateScript({Test-Path -Path $_})]
    [String]$eucConfigJson = "$PsScriptRoot\..\..\eucConfig.json"
)

$eucConfig = Get-Content -Path $eucConfigJson | ConvertFrom-Json

#Clear-Host 
#Write-Host `n `n `n `n `n `n `n

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

Connect-VIServer -Server $viServer -User $horizonServiceAccount -Password $horizonServiceAccountPassword
connect-hvserver -server $horizonServer -User $horizonServiceAccount -password $horizonServiceAccountPassword
$ViewAPI = $global:DefaultHVServers.extensiondata
$datacenterName = $eucConfig.pool.datacenterName


foreach ($newPool in $eucConfig.horizonConfig.pool.desktopPool) {
    $viServer = $newPool.vCenter
    $horizonServiceAccount = If($eucConfig.horizonServiceAccount.Username){$eucConfig.horizonServiceAccount.Username} Else { throw "Horizon service account username not set"}
    $horizonServiceAccountPassword = If($eucConfig.horizonServiceAccount.Password){$eucConfig.horizonServiceAccount.Password} Else {throw "Horizon service account password not set"}
    $horizonConnectionServerURL = If($eucConfig.horizonConfig.connectionServers.horizonConnectionServerURL){$eucConfig.horizonConfig.connectionServers.horizonConnectionServerURL} Else {throw Horizon connection server global URL not set}

	$poolType = [string]$newPool.PoolType.toupper()
    
    # Create a folder for the Desktop Pool VMs
    $folderName = $newPool.VmFolder

    if(get-Folder -Name $folderName -ErrorAction Ignore){
        Write-Host "Found an existing $foldername VM Folder in vCenter. This is where the desktops will be deployed." -BackgroundColor Yellow -ForegroundColor Black `n
    } Else {
        Write-Host "The $foldername VM folder does not exist, creating a new folder" -BackgroundColor Yellow -ForegroundColor Black `n
        (Get-View (Get-View -viewtype datacenter -filter @{"name"="$datacenterName"}).vmfolder).CreateFolder("$folderName") | Out-Null
    }

    # Change the network on the master VM template so that the pool provisions to the correct Network
    $masterVM = $newPool.ParentVM
    $networkAdapter = Get-VM $masterVM | Get-NetworkAdapter -Name "Network adapter 1"
    $networkPortGroup =  Get-VDPortgroup -Name $newPool.networkPortGroup
    Set-NetworkAdapter -NetworkAdapter $networkAdapter -Portgroup $networkPortGroup
    
    switch ($poolType){
		"INSTANTCLONE"{ 
			$message = "Creating new pool $poolType named $($newPool.PoolName)"
			#runlog -functionIn $MyInvocation.MyCommand -runMessage $message
            New-HVPool -InstantClone -PoolName $newPool.PoolName -PoolDisplayName $newPool.PoolDisplayName -Description $newPool.Description -UserAssignment $newPool.UserAssignment -ParentVM $newPool.ParentVM -SnapshotVM $newPool.SnapshotVM -VmFolder $newPool.VmFolder -HostOrCluster $newPool.HostOrCluster -ResourcePool $newPool.ResourcePool -NamingMethod $newPool.NamingMethod -Datastores $newPool.Datastores -NamingPattern  $newPool.NamingPattern -NetBiosName $newPool.NetBiosName -DomainAdmin $newPool.DomainAdmin -vCenter $newPool.vCenter -MinimumCount $newPool.MinimumCount -MaximumCount $newPool.MaximumCount 
        }
        "FULLCLONE"{ 
			$message = "Creating new pool $poolType named $($newPool.PoolName)"
			#runlog -functionIn $MyInvocation.MyCommand -runMessage $message
            New-HVPool -FullClone -PoolName $newPool.PoolName  -PoolDisplayName $newPool.PoolDisplayName  -Description $newPool.Description -UserAssignment $newPool.UserAssignment -VmFolder $newPool.VmFolder -HostOrCluster $newPool.HostOrCluster -ResourcePool $newPool.ResourcePool -NamingMethod $newPool.NamingMethod -Datastores $newPool.Datastores -NamingPattern  $newPool.NamingPattern -NetBiosName $newPool.NetBiosName -vCenter $newPool.vCenter  -Template $newPool.Template -SysPrepName $newPool.SysPrepName -CustType $newPool.CustType
        }			    
        default {runlog -functionIn $MyInvocation.MyCommand -runMessage "Pool Type $poolType Not Implemented"}
	}
	
    #need to let the pool finish being created before doing the entitlement
    Start-Sleep -Seconds 60
    #if it exists, do the entitlement
    foreach ($entitlement in $newPool.entitlement){
        if (![string]::IsNullOrEmpty($entitlement.group)){
            foreach ($group in $entitlement.group){
                New-HVEntitlement -User $group -ResourceName $newPool.PoolName -ResourceType Desktop -Type Group
            }	
        }
        
        if (![string]::IsNullOrEmpty($entitlement.user)){
            foreach ($user in $entitlement.user){
                New-HVEntitlement -User $user -ResourceName $newPool.PoolName -ResourceType Desktop -Type User
            }
        }
    }
}