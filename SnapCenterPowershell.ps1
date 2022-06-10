# Written by Daniel Maryuma (Professional Services Consultant) dmaryuma@netapp.com #

# This script will demonstrate how to use common tasks such as Backup, Restore, Clone backup
# The commands can be executed from /opt/NetApp/snapcenter/spl/bin/sccli
# logs are locate in /var/opt/snapcenter/logs

# To install the module you can copy SnapCenter module from either SnapCenter Server or machine plug-in installed on
# located in "C:\Windows\System32\WindowsPowerShell\v1.0\Modules\SnapCenter
$csv_path = "C:\Users\Administrator.DEMO\Documents\oracle_configs.csv"
$config_xml = "C:\Users\Administrator.DEMO\Documents\config_orclcdb.xml"
try{
    $csv = import-csv $csv_path -Delimiter ","
    $backup_config_xml = [xml](get-content $config_xml)
    $cred = Get-Credential
    Import-Module SnapCenter
    # You should have added the storage system connections and created the credential
    Open-SmConnection -Credential $cred -SMSbaseUrl https://snapctr.demo.netapp.com:8146
}catch {Write-Host $_}


$SmHosts = Get-SmHost
$SmPolicies = Get-SmPolicy
$SmResources = Get-SmResources -PluginCode 'SCO' -HostName $SmHosts[0].HostName -UseKnownResources
$Resources = $SmHosts | Get-SmResources -PluginCode 'SCO' -UseKnownResources
$SmResourceGroup = Get-SmResourceGroup



####################################### BACKUP ############################################

function SmBackup($SmHost,$SmDB,$SmPolicy){    
    $BackupJob = New-SmBackup -Resources @{"Host"=$SmHost;"Oracle Database"=$SmDB} -Policy $SmPolicy -Confirm:$false
    return $BackupJob
}

####################################### Mount ############################################

function SmMount($SmHost,$SmPolicy,$SmResourceGroup,$SmBackup,$SmInstance,$SmMountToHost){
    $AppObjectID = "$SmHost\$SmInstance"
    Write-Host $AppObjectID
    Write-Host "Backup $($SmBackup) will be Mount on path:"
    Write-Host "/var/opt/snapcenter/sco/backup_mount/$($SmBackup)/$SmResourceGroup"
    $SmMountJob = New-SmMountBackup -AppObjectId $AppObjectID -HostName $SmMountToHost -BackupName $SmBackup -Confirm:$false -ErrorAction stop
    return $SmMountJob
}
####################################### UnMount ############################################

function SmUnmount($SmBackup){
    $UnMountJob = New-SmUnmountBackup -BackupName $SmBackup.BackupName -Confirm:$false -ErrorAction stop
    return $UnMountJob
}

####################################### RESTORE ############################################

function SmRestore($SmHost,$SmBackup,$SmInstance){
    $AppObjectID = "$SmHost\$SmInstance"
    $SmRestoreJob = Restore-SmBackup -PluginCode 'SCO' -BackupName $SmBackup.BackupName -AppObjectId $SmInstance -Confirm:$false
    return $SmRestoreJob
}

####################################### CLONE ############################################

function SmClone($SmBackup,$SmHost,$SmInstance,$SmCloneToInstance,$BackupConfigXML){
    $AppObjectID = "$SmHost\$SmInstance"

    $SmCloneJob = New-SmClone -BackupName $BackupConfigXML.'oracle-clone-specification'.backupname `
    -Resources @{"Host"=$SmHost;"Oracle Database"=$SmInstance} `
    -CloneToInstance $SmCloneToInstance `
    -DatabaseSID $BackupConfigXML.'oracle-clone-specification'.'clone-database-sid' `
    -LogRestoreType All `
    -AppPluginCode SCO `
    -OracleOsUserName oracle `
    -OracleOsUserGroup oinstall `
    -AutoAssignMountPoint `
    -ControlFileConfiguration @{"FilePath"=""}
}

####################################### REFRESH CLONE ############################################

 New-SmClone -OracleOsUserName oracle -OracleOsUserGroup oinstall -BackupName "auto-nfs_gdl_englab_netapp_com_nasdb_05-02-2018_08.39.11.5184_0" -AppPluginCode SCO -DatabaseSID Clon32 -Resources @{"Host"="auto-nfs.gdl.englab.netapp.com";"Oracle
    Database"="nasdb"} -AutoAssignMountPoint -CloneToInstance auto-nfs.gdl.englab.netapp.com -ControlFileConfiguration @{"FilePath"="/mnt/Data_Clon32/Clon32/control/control01.ctl"} -RedoLogFileConfiguration @{"FilePath"="/mnt/Data_Clon32/Clon32/redolog/redo01.log";"Redo
    logNumber"="3";"TotalSize"="50";"BlockSize"="512"},@{"FilePath"="/MntPt_StaDB/Data_Clon32/Clon32/redolog/redo02.log";"RedologNumber"="2";"TotalSize"="50";"BlockSize"="512"},@{"FilePath"="/MntPt_StaDB/Data_Clon32/Clon32/redolog/redo03.log";"RedologNumber"="1";"TotalS
    ize"="50";"BlockSize"="512"} -CustomParameters @{"Key" = "audit_file_dest";"Value"="/var/test"} -archivedlocators @{Primary="10.225.118.251:auto_nfs_data";Secondary="ongqathree_man:ongqaone_man_auto_nfs_data_vault"} -logarchivedlocators
    @{Primary="10.225.118.251:auto_nfs_log";Secondary="ongqathree_man:ongqaone_man_auto_nfs_log_vault"}

function FollowJob($job){
    while($true){
    $jobLog = Get-SmJobSummaryReport -JobId $job.Id
    $date = get-date
    if (!$job){Write-Host "No jobs to follow";break}
    if ($jobLog.Status -like "Completed"){
        $jobLog
        Write-Host "jobLog $($jobLog.SmJobId) finished Suucesfully" -ForegroundColor Green
        break
    }elseif ($jobLog.Status -like "Failed"){
        Write-Host "jobLog $($jobLog.SmJobId) Failed:" -ForegroundColor red
        Write-Host $jobLog.JobError
        break
    }else{
        Write-Host "job $($jobLog.SmJobId) Still Running..."
        $jobLog
        Start-Sleep 5}
    if ($date.AddSeconds($TimeLimit) -lt (get-date)){
        Write-Host "Time for job exceeds"
        break
    }
}
}

###################### MAIN #######################
$TimeLimit = 180 # Limit seconds for running a job

# Create Backup:
try{
    $BackupJob = SmBackup -SmHost $csv[0].Host -SmDB $csv[0].InstanceName -SmPolicy ORACLE_DAILY
}catch{Write-Host $_}

# Follow job
FollowJob -job $BackupJob

# Mount Backup: #### Cannot mount to other host.. ####
try{
    $SmBackups = get-smbackup -Details | ?{$_.isMounted -notlike "true"} -ErrorAction stop
    $SmBackup = ($SmBackups | ?{$_.BackupType -like "Oracle Database Data Backup" -and $_.policyName -eq "ORACLE_DAILY" -and $_.protectiongroupname -like $csv[0].SmResourceGroup} | Sort-Object -ErrorAction stop -Property BackupTime -Descending)[0] 
    Write-Host "The Backup that will be mount: "
    Write-Host $SmBackup.BackupName
    $SmMountJob = SmMount -SmHost $csv[0].Host -SmPolicy "ORACLE_DAILY" -SmResourceGroup $csv[0].SmResourceGroup -SmBackup $SmBackup.BackupName -SmInstance $csv[0].InstanceName -SmMountToHost $csv[0].MountToHost
}catch{
    if ($Error[0].Exception.Message -like "*Cannot index into a null array*"){
        Write-Host "Cannot index into a null array"
        Write-Host "No Backups found to sepcify the request"
    }
    else {Write-Host $_}
}
FollowJob -job $SmMountJob

# UnMount Backup:
try{
    $SmBackups = get-smbackup -Details | ?{$_.isMounted -like "true"} -ErrorAction stop
    $SmBackup = ($SmBackups | ?{$_.BackupType -like "Oracle Database Data Backup" -and $_.policyName -eq "ORACLE_DAILY" -and $_.protectiongroupname -like $csv[0].SmResourceGroup} | Sort-Object -ErrorAction stop -Property BackupTime -Descending)[0] 
    Write-Host "The Backup that will be Unmount: "
    Write-Host "$($SmBackup.BackupName)"
    $SmUnMountJob = SmUnmount -SmBackup $SmBackup
}catch{
    if ($Error[0].Exception.Message -like "*Cannot index into a null array*"){
        Write-Host "Cannot index into a null array"
        Write-Host "No Backups found to sepcify the request"
    }
    else {Write-Host $_}
}
FollowJob -job $SmUnMountJob

# Restore from Backup:
