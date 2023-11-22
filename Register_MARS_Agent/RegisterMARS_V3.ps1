<#
.SYNOPSIS
    This script is designed to register the MARS Agent with specified parameters.

.DESCRIPTION
    The script takes in several mandatory parameters related to the target tenant, application, resource group, vault, backup settings, and more. 
    It then establishes a connection to Azure using the provided credentials and retrieves the specified Recovery Services vault object. 
    The script also contains a custom logging function to capture and log the script's activities.

.INPUT PARAMETERS
    - TargetTennantID: The ID of the target tenant.
    - TargetAppID: The ID of the target application (Service Principal).
    - TargetAppID_Secret: The secret key for the target application ID.
    - TargetResourceGroupName: The name of the target resource group.
    - TargetVaultName: The name of the target Recovery Services vault.
    - TargetSettingPassphrase: The passphrase for the target setting.
    - TargetWorkHoursStart: The start time of the target work hours.
    - TargetWorkHoursEnd: The end time of the target work hours.
    - TargetWorkHourBandwidthMbps: The upload speed during work hours.
    - TargetNonWorkHourBandwidthMbps: The upload speed during non-work hours.
    - TargetFilesBackupExecDay: The execution day for file backups.
    - TargetFilesBackupExecTime: The execution time for file backups.
    - TargetFilesBackupRetentionDays: The retention period for file backups.
    - TargetSystemStateBackupExecDay: The execution day for system state backups.
    - TargetSystemStateBackupExecTime: The execution time for system state backups.
    - TargetSystemStateRetentionDays: The retention period for system state backups.

.ERROR CODES
    - Error Code 1: FAILED to connect to Azure.
    - Error Code 2: FAILED to retrieve vault object.
    - Error Code 3: FAILED to download Vault Credentials file.
    - Error Code 4: FAILED to import MSOnlineBackup PS Module.
    - Error Code 5: FAILED to Register machine.
    - Error Code 6: FAILED to set encryption passphrase.
    - Error Code 7: FAILED to disable proxies.
    - Error Code 8: FAILED to configure work hours and throttling settings.
    - Error Code 9: FAILED to apply Files Backup Schedule to the Files Backup policy.
    - Error Code 10: FAILED to apply Files Backup Retention Policy to the Files Backup policy.
    - Error Code 11: FAILED to get logical disks info.
    - Error Code 12: FAILED to apply Files Backup Item Inclusion Policy to the Files Backup Policy.
    - Error Code 13: FAILED to apply Files Backup policy.
    - Error Code 14: FAILED to add System State capability to System State Backup Policy object.
    - Error Code 15: FAILED to apply System State Backup Schedule to the System State Backup policy.
    - Error Code 16: FAILED to apply System State Backup Retention Policy to the System State Backup policy.
    - Error Code 17: FAILED to apply System State Backup policy.

.EXAMPLE
    .\RegisterMARS_V3.ps1 -TargetTennantID 'xxxx' -TargetAppID 'xxxx' -TargetAppID_Secret 'xxxx' -TargetResourceGroupName 'xxxx' -TargetVaultName 'xxxx' -TargetSettingPassphrase 'xxxx' -TargetWorkHoursStart '08:00' -TargetWorkHoursEnd '17:00' -TargetWorkHourBandwidthMbps 100 -TargetNonWorkHourBandwidthMbps 50 -TargetFilesBackupExecDay 'Monday' -TargetFilesBackupExecTime '02:00' -TargetFilesBackupRetentionDays 30 -TargetSystemStateBackupExecDay 'Tuesday' -TargetSystemStateBackupExecTime '03:00' -TargetSystemStateRetentionDays 30

.NOTES
    - Ensure that you have the necessary permissions to connect to Azure and access the specified resources.
    - The script creates log folders and files in the "C:\Temp" directory. Ensure that the directory exists or modify the script to use a different directory.
    - Always review and test the script in a safe environment before running it in production.

Last Edit: Oct 20th, 2023

-V3
--Fixed Typos in comments section
--Added subroutine for getting all logical drives, with free space greater than 0 bytes and adding them to the Files Backup Policy.
--Added capability to delete passhrase backup txt after registration due to security concerns. Failure to delte it is non-critical and the script execution continues regardless.

#>


param(
    [Parameter(Mandatory=$true)]
    [string]$TargetTennantID,
    [Parameter(Mandatory=$true)]
    [string]$TargetAppID,
    [Parameter(Mandatory=$true)]
    [string]$TargetAppID_Secret,
    [Parameter(Mandatory=$true)]
    [string]$TargetResourceGroupName,
    [Parameter(Mandatory=$true)]
    [string]$TargetVaultName,
    [Parameter(Mandatory=$true)]
    [string]$TargetSettingPassphrase,
    [Parameter(Mandatory=$true)]
    [string]$TargetWorkHoursStart,
    [Parameter(Mandatory=$true)]
    [string]$TargetWorkHoursEnd,
    [Parameter(Mandatory=$true)]
    [uint32]$TargetWorkHourBandwidthMbps,
    [Parameter(Mandatory=$true)]
    [uint32]$TargetNonWorkHourBandwidthMbps,
    [Parameter(Mandatory=$true)]
    [string]$TargetFilesBackupExecDay,
    [Parameter(Mandatory=$true)]
    [string]$TargetFilesBackupExecTime,
    [Parameter(Mandatory=$true)]
    [long]$TargetFilesBackupRetentionDays,
    [Parameter(Mandatory=$true)]
    [string]$TargetSystemStateBackupExecDay,
    [Parameter(Mandatory=$true)]
    [string]$TargetSystemStateBackupExecTime,
    [Parameter(Mandatory=$true)]
    [long]$TargetSystemStateRetentionDays
)

# Capture script directory
$ScriptDir = $PSScriptRoot

# Define log folder root
$LogFolderRoot = "C:\Temp"

# Create folders if they don't exist
if(!(Test-Path -Path $LogFolderRoot)) {
    New-Item -ItemType Directory -Force -Path $LogFolderRoot
}

# Define log folder path
$LogFolderPath = "C:\Temp\RegisterMARS"

# Define path to store Vault credentials file
$CredsPath = $LogFolderPath

# Create folders if they don't exist
if(!(Test-Path -Path $LogFolderPath)) {
    New-Item -ItemType Directory -Force -Path $LogFolderPath
}

# Custom logging function
function debug($message) {
    $logMessage = "$(Get-Date -Format yyyy-MM-dd--HH-mm-ss) $message"
    Write-Host $logMessage
    Add-Content -Path "$LogFolderPath\MARS_Setup_$(Get-Date -Format yyyy_MM_dd__HH).log" -Value $logMessage -Force
}

debug "------------------------------------------------------------------------------------------------------------------------------------------------"

debug "Script initated."

debug "Input Parameters:"
debug "Target Tennant ID: $TargetTennantID"
debug "Target Application ID (Service Principal): $TargetAppID"
debug "Target Resource Group Name: $TargetResourceGroupName"
debug "Target Recovery Services Vault Name: $TargetVaultName"
debug "Target Work Hours Start: $TargetWorkHoursStart"
debug "Target Work Hours End: $TargetWorkHoursEnd"
debug "Target Upload speed during work hours in Mbps: $TargetWorkHourBandwidthMbps"
debug "Target Upload speed during NON-work hours in Mbps: $TargetNonWorkHourBandwidthMbps"
debug "Target Files Backup Execution Day: $TargetFilesBackupExecDay"
debug "Target Files Backup Execution Time: $TargetFilesBackupExecTime"
debug "Target Files Backup Retention Days: $TargetFilesBackupRetentionDays"
debug "Target System State Backup Execution Day: $TargetSystemStateBackupExecDay"
debug "Target System State Backup Execution Time: $TargetSystemStateBackupExecTime"
debug "Target System State Backup Retention Days: $TargetSystemStateRetentionDays"

debug "-------------------------------------------"
debug "ACTION 1: Register MARS Agent"
debug "-------------------------------------------"

debug "Constructing Credential Object for target AppID $TargetAppID..."

$SecurePassword = ConvertTo-SecureString -String $TargetAppID_Secret -AsPlainText -Force

$Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $TargetAppID, $SecurePassword

debug "Credential constructed. Connecting to Azure..."


Connect-AzAccount -ServicePrincipal -TenantId $TargetTennantID -Credential $Credential -ErrorAction SilentlyContinue

if($Error[0])
{
    debug "FAILED to connect to Azure. Error: $($Error[0].Exception.Message)"

    debug "Exiting script with error code 1..."

    debug "------------------------------------------------------------------------------------------------------------------------------------------------"

    $Error.Clear()
    
    exit 1
}

debug "Azure Connection established successfully."

debug "Retrieving Target Recovery Services vault $TargetVaultName SRVault object..."

$TargetVaultObject = Get-AzRecoveryServicesVault -ResourceGroupName $TargetResourceGroupName -Name $TargetVaultName -ErrorAction SilentlyContinue

if($Error[0])
{
    debug "FAILED to retrieve vault object. Error: $($Error[0].Exception.Message)"

    debug "Disconnecting AzAccount..."

    Disconnect-AzAccount -Confirm:$false

    debug "AzAccount disconnected."

    debug "Exiting script with error code 2..."

    debug "------------------------------------------------------------------------------------------------------------------------------------------------"

    $Error.Clear()
    
    exit 2
}

debug "Vault object retrieved successfully."

debug "Downloading Vault Credentials file to $CredsPath..."

Get-AzRecoveryServicesVaultSettingsFile -Backup -Vault $TargetVaultObject -Path $CredsPath -ErrorAction SilentlyContinue
if($Error[0])
{
    debug "FAILED to download Vault Credentials file. Error: $($Error[0].Exception.Message)"

    debug "Disconnecting AzAccount..."

    Disconnect-AzAccount -Confirm:$false

    debug "AzAccount disconnected."

    debug "Exiting script with error code 3..."

    debug "------------------------------------------------------------------------------------------------------------------------------------------------"

    $Error.Clear()
    
    exit 3
}

debug "Vault Credentials file downloaded successfully. Obtaining File Path..."

debug "Getting Vault Credentials File path...."

$CredsFilePathObj = Get-Item -Path "$CredsPath\$TargetVaultName*" -Force

$CredsFilePathCleanString = $CredsFilePathObj.FullName

debug "Vault Credentials full file path: $CredsFilePathCleanString"

debug "Importing MSOnlineBackup PS Module..."

Import-Module MSOnlineBackup

$moduleImportedCheck = Get-Module MSOnlineBackup

if(!($moduleImportedCheck))
{
    debug "FAILED to import MSOnlineBackup PS Module. Error: $($Error[0].Exception.Message)"

    debug "Disconnecting AzAccount..."

    Disconnect-AzAccount -Confirm:$false

    debug "AzAccount disconnected."

    debug "Exiting script with error code 4..."

    debug "------------------------------------------------------------------------------------------------------------------------------------------------"

    $Error.Clear()
    
    exit 4
}

debug "MSOnlineBackup PS Module imported successfully."

debug "Starting the registration process..."

Start-OBRegistration -VaultCredentials $CredsFilePathCleanString -Confirm:$false -ErrorAction SilentlyContinue

if($Error[0])
{
    debug "FAILED to Register machine. Error: $($Error[0].Exception.Message)"

    debug "Please also check CBEngineCurr.errlog (default location: C:\Program Files\Microsoft Azure Recovery Services Agent\Temp\CBEngineCurr.errlog) "

    debug "Disconnecting AzAccount..."

    Disconnect-AzAccount -Confirm:$false

    debug "AzAccount disconnected."

    debug "Exiting script with error code 5..."

    debug "------------------------------------------------------------------------------------------------------------------------------------------------"

    $Error.Clear()
    
    exit 5
}

debug "Configuring Machine Settings | Setting passphrase..."

$TargetPassphraseSecure = ConvertTo-SecureString -String $TargetSettingPassphrase -AsPlainText -Force

Set-OBMachineSetting -EncryptionPassphrase $TargetPassphraseSecure -PassphraseSaveLocation $LogFolderPath -Confirm:$false -ErrorAction SilentlyContinue

if($Error[0])
{
    debug "FAILED to set encryption passphrase. Error: $($Error[0].Exception.Message)"

    debug "Please also check CBEngineCurr.errlog (default location: C:\Program Files\Microsoft Azure Recovery Services Agent\Temp\CBEngineCurr.errlog) "

    debug "Disconnecting AzAccount..."

    Disconnect-AzAccount -Confirm:$false

    debug "AzAccount disconnected."

    debug "Exiting script with error code 6..."

    debug "------------------------------------------------------------------------------------------------------------------------------------------------"

    $Error.Clear()
    
    exit 6
}

debug "Passphrase setting complete. Deleting generated .txt file...."

$PassphraseSaveTXTObj = Get-Item -Path "$LogFolderPath\*_$TargetVaultName_$env:COMPUTERNAME.txt" -Force

$PassphraseSaveTXTObjCleanString = $PassphraseSaveTXTObj.FullName

debug "Generated Passphrase save TXT file full file path: $PassphraseSaveTXTObjCleanString"

Remove-Item -Path $PassphraseSaveTXTObjCleanString -Force -Confirm:$false -ErrorAction SilentlyContinue | Out-Null

$DeletionCheck = Test-Path -Path $PassphraseSaveTXTObjCleanString -PathType Leaf

if($false -eq $DeletionCheck)
{
    debug "Generated Passphrase backup TXT deleted successfully."
}
else
{
    debug "FAILED to delete Generated Passphrase backup TXT. Script execution will continue."

    $Error.Clear()
}


debug "Configuring Machine Settings | Disabling Proxies..."

Set-OBMachineSetting -NoProxy -Confirm:$false -ErrorAction SilentlyContinue

if($Error[0])
{
    debug "FAILED to disable proxies. Error: $($Error[0].Exception.Message)"

    debug "Please also check CBEngineCurr.errlog (default location: C:\Program Files\Microsoft Azure Recovery Services Agent\Temp\CBEngineCurr.errlog) "

    debug "Disconnecting AzAccount..."

    Disconnect-AzAccount -Confirm:$false

    debug "AzAccount disconnected."

    debug "Exiting script with error code 7..."

    debug "------------------------------------------------------------------------------------------------------------------------------------------------"

    $Error.Clear()
    
    exit 7
}

debug "Configuring Machine Settings | Configuring Work hours and throttling settings..."

$WorkHoursStartVariable = [TimeSpan]::Parse($TargetWorkHoursStart)

$WorkHoursEndVariable = [TimeSpan]::Parse($TargetWorkHoursEnd)

Set-OBMachineSetting -WorkDay Monday, Tuesday, Wednesday, Thursday, Friday -StartWorkHour $WorkHoursStartVariable -EndWorkHour $WorkHoursEndVariable -WorkHourBandwidth ($TargetWorkHourBandwidthMbps*1024*1024) -NonWorkHourBandwidth ($TargetNonWorkHourBandwidthMbps*1024*1024) -Confirm:$false -ErrorAction SilentlyContinue

if($Error[0])
{
    debug "FAILED to configure work hours and throttling settings. Error: $($Error[0].Exception.Message)"

    debug "Please also check CBEngineCurr.errlog (default location: C:\Program Files\Microsoft Azure Recovery Services Agent\Temp\CBEngineCurr.errlog) "

    debug "Disconnecting AzAccount..."

    Disconnect-AzAccount -Confirm:$false

    debug "AzAccount disconnected."

    debug "Exiting script with error code 8..."

    debug "------------------------------------------------------------------------------------------------------------------------------------------------"

    $Error.Clear()
    
    exit 8
}

debug "Configuring machine settings complete."

debug "------------------------------------------------"

debug "ACTION 2: Configure Files Backup"

debug "------------------------------------------------"

debug "Creating Policy Object..."

$FilesBackupPolicy = New-OBPolicy

debug "Configuring Backup Schedule..."

switch -Exact ($TargetFilesBackupExecDay)
{
    "Monday"
    {
        $SchedDayVariable = [System.DayOfWeek]::Monday
        break
    }
    "Tuesday"
    {
        $SchedDayVariable = [System.DayOfWeek]::Tuesday
        break
    }
    "Wednesday"
    {
        $SchedDayVariable = [System.DayOfWeek]::Wednesday
        break
    }
    "Thursday"
    {
        $SchedDayVariable = [System.DayOfWeek]::Thursday
        break
    }
    "Friday"
    {
        $SchedDayVariable = [System.DayOfWeek]::Friday
        break
    }
    "Saturday"
    {
        $SchedDayVariable = [System.DayOfWeek]::Saturday
        break
    }
    "Sunday"
    {
        $SchedDayVariable = [System.DayOfWeek]::Sunday
        break
    }
}

$SchedTimeVariable = [TimeSpan]::Parse($TargetFilesBackupExecTime)

$FilesBackupSchedule = New-OBSchedule -DaysOfWeek $SchedDayVariable -TimesOfDay $SchedTimeVariable -WeeklyFrequency 1

debug "Configured Files Backup Schedule to execute on $SchedDayVariable at $SchedTimeVariable every week."

debug "Applying Files Backup Schedule to the Files Backup Policy..."

Set-OBSchedule -Policy $FilesBackupPolicy -Schedule $FilesBackupSchedule -Confirm:$false -ErrorAction SilentlyContinue

if($Error[0])
{
    debug "FAILED to apply Files Backup Schedule to the Files Backup policy. Error: $($Error[0].Exception.Message)"

    debug "Please also check CBEngineCurr.errlog (default location: C:\Program Files\Microsoft Azure Recovery Services Agent\Temp\CBEngineCurr.errlog) "

    debug "Disconnecting AzAccount..."

    Disconnect-AzAccount -Confirm:$false

    debug "AzAccount disconnected."

    debug "Exiting script with error code 9..."

    debug "------------------------------------------------------------------------------------------------------------------------------------------------"

    $Error.Clear()
    
    exit 9
}

debug "Files Backup Schedule applied successfully."

debug "Configuring Retention Policy..."

$FilesBackupRetentionPolicy = New-OBRetentionPolicy -RetentionDays $TargetFilesBackupRetentionDays -

debug "Configured Files Backup Retention length to $TargetFilesBackupRetentionDays days."

debug "Applying Files Retention Policy to the Files Backup Policy..."

Set-OBRetentionPolicy -Policy $FilesBackupPolicy -RetentionPolicy $FilesBackupRetentionPolicy -Confirm:$false -ErrorAction SilentlyContinue

if($Error[0])
{
    debug "FAILED to apply Files Backup Retention Policy to the Files Backup policy. Error: $($Error[0].Exception.Message)"

    debug "Please also check CBEngineCurr.errlog (default location: C:\Program Files\Microsoft Azure Recovery Services Agent\Temp\CBEngineCurr.errlog) "

    debug "Disconnecting AzAccount..."

    Disconnect-AzAccount -Confirm:$false

    debug "AzAccount disconnected."

    debug "Exiting script with error code 10..."

    debug "------------------------------------------------------------------------------------------------------------------------------------------------"

    $Error.Clear()
    
    exit 10
}

debug "Files Backup Retention Policy applied successfully."

debug "Configuring Files inclusion policy... "

debug "Retrieving all logical drives..."

$DisksInfo = Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue

if($Error[0])
{
    debug "FAILED to retrieve info on logical disks. Error: $($Error[0].Exception.Message)"

    debug "Disconnecting AzAccount..."

    Disconnect-AzAccount -Confirm:$false

    debug "AzAccount disconnected."

    debug "Exiting script with error code 11..."

    debug "------------------------------------------------------------------------------------------------------------------------------------------------"

    $Error.Clear()
    
    exit 11
}

debug "Logical Disks info retrieved succesfully."

debug "Extracting Root Dirs for each disk..."

$LogicalDiskRoots = @()

foreach($Disk in $DisksInfo)
{
    if($Disk.Free -ge 0)
    {
        $LogicalDiskRoots = $LogicalDiskRoots + $Disk.Root
    }
}

debug "------------------------------------------------"

debug "Extracted Root Dirs:"

debug $LogicalDiskRoots

debug "------------------------------------------------"

$FilesBackupInclusionPolicy = New-OBFileSpec -FileSpec $LogicalDiskRoots

debug "Configured Files Backup Item Inclusion Policy to drives $LogicalDiskRoots."

debug "Applying Files Backup Item Inclusion Policy to the Files Backup Policy..."

Add-OBFileSpec -Policy $FilesBackupPolicy -FileSpec $FilesBackupInclusionPolicy -Confirm:$false -ErrorAction SilentlyContinue

if($Error[0])
{
    debug "FAILED to Apply Files Backup Item Inclusion Policy to the Files Backup Policy. Error: $($Error[0].Exception.Message)"

    debug "Please also check CBEngineCurr.errlog (default location: C:\Program Files\Microsoft Azure Recovery Services Agent\Temp\CBEngineCurr.errlog) "

    debug "Disconnecting AzAccount..."

    Disconnect-AzAccount -Confirm:$false

    debug "AzAccount disconnected."

    debug "Exiting script with error code 12..."

    debug "------------------------------------------------------------------------------------------------------------------------------------------------"

    $Error.Clear()
    
    exit 12
}

debug "Files Backup Item Inclusion Policy applied successfully."

debug "Applying Files Backup policy..."

Set-OBPolicy -Policy $FilesBackupPolicy -Confirm:$false -ErrorAction SilentlyContinue

if($Error[0])
{
    debug "FAILED to apply Files Backup policy. Error: $($Error[0].Exception.Message)"

    debug "Please also check CBEngineCurr.errlog (default location: C:\Program Files\Microsoft Azure Recovery Services Agent\Temp\CBEngineCurr.errlog) "

    debug "Disconnecting AzAccount..."

    Disconnect-AzAccount -Confirm:$false

    debug "AzAccount disconnected."

    debug "Exiting script with error code 13..."

    debug "------------------------------------------------------------------------------------------------------------------------------------------------"

    $Error.Clear()
    
    exit 13
}

debug "Files Backup Policy applied Successfully."

debug "------------------------------------------------"

debug "ACTION 3: Configure System State Backup"

debug "------------------------------------------------"

debug "Creating Policy Object..."

$SystemStateBackupPolicy = New-OBPolicy

debug "Adding System State capability to policy object..."

Add-OBSystemState -Policy $SystemStateBackupPolicy -Confirm:$false -ErrorAction SilentlyContinue

if($Error[0])
{
    debug "FAILED to Add System State capability to System State Backup Policy object. Error: $($Error[0].Exception.Message)"

    debug "Please also check CBEngineCurr.errlog (default location: C:\Program Files\Microsoft Azure Recovery Services Agent\Temp\CBEngineCurr.errlog) "

    debug "Disconnecting AzAccount..."

    Disconnect-AzAccount -Confirm:$false

    debug "AzAccount disconnected."

    debug "Exiting script with error code 14..."

    debug "------------------------------------------------------------------------------------------------------------------------------------------------"

    $Error.Clear()
    
    exit 14
}

debug "Configuring Backup Schedule..."

switch -Exact ($TargetSystemStateBackupExecDay)
{
    "Monday"
    {
        $SchedDayVariable = [System.DayOfWeek]::Monday
        break
    }
    "Tuesday"
    {
        $SchedDayVariable = [System.DayOfWeek]::Tuesday
        break
    }
    "Wednesday"
    {
        $SchedDayVariable = [System.DayOfWeek]::Wednesday
        break
    }
    "Thursday"
    {
        $SchedDayVariable = [System.DayOfWeek]::Thursday
        break
    }
    "Friday"
    {
        $SchedDayVariable = [System.DayOfWeek]::Friday
        break
    }
    "Saturday"
    {
        $SchedDayVariable = [System.DayOfWeek]::Saturday
        break
    }
    "Sunday"
    {
        $SchedDayVariable = [System.DayOfWeek]::Sunday
        break
    }
}

$SchedTimeVariable = [TimeSpan]::Parse($TargetSystemStateBackupExecTime)

$SystemStateBackupSchedule = New-OBSchedule -DaysOfWeek $SchedDayVariable -TimesOfDay $SchedTimeVariable -WeeklyFrequency 1

debug "Configured System State Backup Schedule to execute on $SchedDayVariable at $SchedTimeVariable every week."

debug "Applying Files Backup Schedule to the Files Backup Policy..."

Set-OBSchedule -Policy $SystemStateBackupPolicy -Schedule $SystemStateBackupSchedule -Confirm:$false -ErrorAction SilentlyContinue

if($Error[0])
{
    debug "FAILED to apply System State Backup Schedule to the System State Backup policy. Error: $($Error[0].Exception.Message)"

    debug "Please also check CBEngineCurr.errlog (default location: C:\Program Files\Microsoft Azure Recovery Services Agent\Temp\CBEngineCurr.errlog) "

    debug "Disconnecting AzAccount..."

    Disconnect-AzAccount -Confirm:$false

    debug "AzAccount disconnected."

    debug "Exiting script with error code 15..."

    debug "------------------------------------------------------------------------------------------------------------------------------------------------"

    $Error.Clear()
    
    exit 15
}

debug "System State Backup Schedule applied successfully."

debug "Configuring Retention Policy..."

$SystemStateBackupRetentionPolicy = New-OBRetentionPolicy -RetentionDays $TargetSystemStateRetentionDays

debug "Configured System State Backup Retention length to $TargetSystemStateRetentionDays days."

debug "Applying System State Retention Policy to the System State Backup Policy..."

Set-OBRetentionPolicy -Policy $SystemStateBackupPolicy -RetentionPolicy $SystemStateBackupRetentionPolicy -Confirm:$false -ErrorAction SilentlyContinue

if($Error[0])
{
    debug "FAILED to apply System State Backup Retention Policy to the System State Backup policy. Error: $($Error[0].Exception.Message)"

    debug "Please also check CBEngineCurr.errlog (default location: C:\Program Files\Microsoft Azure Recovery Services Agent\Temp\CBEngineCurr.errlog) "

    debug "Disconnecting AzAccount..."

    Disconnect-AzAccount -Confirm:$false

    debug "AzAccount disconnected."

    debug "Exiting script with error code 16..."

    debug "------------------------------------------------------------------------------------------------------------------------------------------------"

    $Error.Clear()
    
    exit 16
}

debug "System State Backup Retention Policy applied successfully."

debug "Applying System State Backup policy..."

Set-OBSystemStatePolicy -Policy $SystemStateBackupPolicy -Confirm:$false -ErrorAction SilentlyContinue

if($Error[0])
{
    debug "FAILED to apply System State Backup policy. Error: $($Error[0].Exception.Message)"

    debug "Please also check CBEngineCurr.errlog (default location: C:\Program Files\Microsoft Azure Recovery Services Agent\Temp\CBEngineCurr.errlog) "

    debug "Disconnecting AzAccount..."

    Disconnect-AzAccount -Confirm:$false

    debug "AzAccount disconnected."

    debug "Exiting script with error code 17..."

    debug "------------------------------------------------------------------------------------------------------------------------------------------------"

    $Error.Clear()
    
    exit 17
}

debug "System State Backup Policy applied Successfully."

debug "Script execution finished successfully. Exiting..."

exit 0