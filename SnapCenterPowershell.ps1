# Written by Daniel Maryuma (Professional Services Consultant) dmaryuma@netapp.com #


# This script will demonstrate how to use common tasks such as Backup, Restore, Clone backup
# The commands can be executed from /opt/NetApp/snapcenter/spl/bin/sccli
# logs are locate in /var/opt/snapcenter/logs

# To install the module you can copy SnapCenter module from either SnapCenter Server or machine plug-in installed on
# located in "C:\Windows\System32\WindowsPowerShell\v1.0\Modules\SnapCenter
$cred = Get-Credential
Import-Module SnapCenter
# You should have added the storage system connections and created the credential
Open-SmConnection -Credential $cred -SMSbaseUrl https://192.168.0.92:8146

$SmHosts = Get-SmHost
$SmPolicies = Get-SmPolicy
$SmResources = Get-SmResources -PluginCode 'SCO' -HostName $SmHosts[0].HostName -UseKnownResources
$Resources = $SmHosts | Get-SmResources -PluginCode 'SCO' -UseKnownResources



####################################### BACKUP ############################################


# Create new Backup:
# syntax for resources :  @{"Host"="scspr0101826001-sumanr.lab.netapp.com";"Oracle Database"="ong"}

try{
    $pos = $SmResources[0].DBId.IndexOf('\')
    $BackupJob = New-SmBackup -Resources @{"Host"=$SmResources[0].DBId.Substring(0,$pos);"Oracle Database"=($SmResources[0].DBName)} -Policy $SmPolicies[0].Name -ErrorAction stop -Confirm:$false
}catch{Write-Host $_}

# Follow the job:
# Get job detail
$job = Get-SmJobSummaryReport -JobId $BackupJob.Id

# Create new backup with verification on secondery system
try{
    $pos = $SmResources[0].DBId.IndexOf('\')
    $BackupJob = New-SmBackup -Resources @{"Host"=$SmResources[0].DBId.Substring(0,$pos);"Oracle Database"=($SmResources[0].DBName)} -Policy $SmPolicies[0].Name -EnableVerification $true -VerifyOnSecondary $true -ErrorAction stop -Confirm:$false
}catch{Write-Host $_}

####################################### Mount ############################################
# get the backup you want to restore from
# example - getting most recent backup for specific ResourceGroupName and Policy
$SmBackup = ((get-smbackup -Details) | ?{$_.BackupType -like "Oracle Database Data Backup" -and $_.policyName -eq $SmPolicies[0].name -and $_.protectiongroupname -like $SmResourceGroup[0].Name} | Sort-Object -Property BackupTime -Descending)[0]
$SmResource = Get-SmResources -PluginCode 'SCO' -HostName $SmHosts[0].HostName -UseKnownResources
$SmMountJob = $SmBackup | New-SmMountBackup -AppObjectId $SmResources[0].DBId -HostName $SmHosts[1].HostName -Confirm:$false

$job = Get-SmJobSummaryReport -JobId $SmMountJob.Id

####################################### UnMount ############################################
# get all backups that are mounted
$jobs = @{}
$AllMountedBackups = get-smbackup -details | ?{$_.isMounted -eq $true}
foreach ($MountedBackup in $AllMountedBackups){
    $UnMountJob = New-SmUnmountBackup -BackupName $MountedBackup.backupname -Confirm:$false
    $jobs += Get-SmJobSummaryReport -JobId $UnMountJob.id
}

####################################### RESTORE ############################################
# get the backup you want to restore from
# example - getting most recent backup for specific ResourceGroupName and Policy
$SmBackup = ((get-smbackup -Details) | ?{$_.BackupType -like "Oracle Database Data Backup" -and $_.policyName -eq $SmPolicies[0].name -and $_.protectiongroupname -like $SmResourceGroup[0].Name} | Sort-Object -Property BackupTime -Descending)[0]
$SmResource = Get-SmResources -PluginCode 'SCO' -HostName $SmHosts[0].HostName -UseKnownResources
try{
    $SmRestoreJob = Restore-SmBackup -PluginCode 'SCO' -BackupName $SmBackup[0].BackupName -AppObjectId $SmResource[1].DBId -Confirm:$false -ErrorAction stop
}catch{Write-Host $_}

$job = Get-SmJobSummaryReport -JobId $SmRestoreJob.Id
# Get status of job:
$job | % -MemberName {write-host $_.JobName $_.Status}

####################################### CLONE ############################################
# get the backup you want to restore from
# example - getting most recent backup for specific ResourceGroupName and Policy
$SmBackup = ((get-smbackup -Details) | ?{$_.BackupType -like "Oracle Database Data Backup" -and $_.policyName -eq $SmPolicies[0].name -and $_.protectiongroupname -like $SmResourceGroup[0].Name} | Sort-Object -Property BackupTime -Descending)[0]
$SmResource = Get-SmResources -PluginCode 'SCO' -HostName $SmHosts[0].HostName -UseKnownResources
try{
    $SmCloneJob = New-SmClone -BackupName $SmBackup.BackupName `
    -Resources @{"Host"=$SmResources[0].DBId.Substring(0,$pos);"Oracle Database"=($SmResources[0].DBName)} `
    -CloneToInstance $SmResources[0].DBId `
    -LogRestoreType All `
    -AppPluginCode SCO `
    -OracleOsUserName sys `
    -OracleOsUserGroup oinstall `
    -AutoAssignMountPoint `
    -ControlFileConfiguration @{"FilePath"=""}

}catch{Write-Host $_}

####################################### REFRESH CLONE ############################################

 New-SmClone -OracleOsUserName oracle -OracleOsUserGroup oinstall -BackupName "auto-nfs_gdl_englab_netapp_com_nasdb_05-02-2018_08.39.11.5184_0" -AppPluginCode SCO -DatabaseSID Clon32 -Resources @{"Host"="auto-nfs.gdl.englab.netapp.com";"Oracle
    Database"="nasdb"} -AutoAssignMountPoint -CloneToInstance auto-nfs.gdl.englab.netapp.com -ControlFileConfiguration @{"FilePath"="/mnt/Data_Clon32/Clon32/control/control01.ctl"} -RedoLogFileConfiguration @{"FilePath"="/mnt/Data_Clon32/Clon32/redolog/redo01.log";"Redo
    logNumber"="3";"TotalSize"="50";"BlockSize"="512"},@{"FilePath"="/MntPt_StaDB/Data_Clon32/Clon32/redolog/redo02.log";"RedologNumber"="2";"TotalSize"="50";"BlockSize"="512"},@{"FilePath"="/MntPt_StaDB/Data_Clon32/Clon32/redolog/redo03.log";"RedologNumber"="1";"TotalS
    ize"="50";"BlockSize"="512"} -CustomParameters @{"Key" = "audit_file_dest";"Value"="/var/test"} -archivedlocators @{Primary="10.225.118.251:auto_nfs_data";Secondary="ongqathree_man:ongqaone_man_auto_nfs_data_vault"} -logarchivedlocators
    @{Primary="10.225.118.251:auto_nfs_log";Secondary="ongqathree_man:ongqaone_man_auto_nfs_log_vault"}
# Jobs
get-smbackupreport

# get-smbackup

# (get-smbackup -Details)[0] 

# (get-smbackup)[0] |  Get-SmBackupReport