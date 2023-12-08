[string]$TargetWorkHoursStart = "00:00"

[string]$TargetWorkHoursEnd = "00:00"

[uint32]$TargetWorkHourBandwidthMbps = 50

[uint32]$TargetNonWorkHourBandwidthMbps = 350

[string]$TargetFilesBackupExecDay = "Monday"

[string]$TargetFilesBackupExecTime = "00:00"

[long]$TargetFilesBackupRetentionDays = 15

[string]$TargetSystemStateBackupExecDay = "Monday"

[string]$TargetSystemStateBackupExecTime = "00:00"

[long]$TargetSystemStateRetentionDays = 15

Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope LocalMachine -Force -Confirm:$false

Remove-Item -Path "C:\Temp\RegisterMARS" -Recurse -Force -Confirm:$false -ErrorAction Ignore

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

debug "Running Lite Version of the MARS Registration Script. Only configuring Machine settings and Backup types and schedules."

debug "Input Parameters:"

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
debug "ACTION 1: Configure Machine Settings"
debug "-------------------------------------------"


debug "Importing MSOnlineBackup PS Module..."

Import-Module MSOnlineBackup

$moduleImportedCheck = Get-Module MSOnlineBackup

if(!($moduleImportedCheck))
{
    debug "FAILED to import MSOnlineBackup PS Module. Error: $($Error[0].Exception.Message)"

    debug "Disconnecting AzAccount..."

    Disconnect-AzAccount -Confirm:$false

    debug "AzAccount disconnected."

    debug "Exiting script with error code 1..."

    debug "------------------------------------------------------------------------------------------------------------------------------------------------"

    $Error.Clear()

    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force -Confirm:$false
    
    exit 1
}

debug "MSOnlineBackup PS Module imported successfully."

debug "Configuring Machine Settings | Disabling Proxies..."

Set-OBMachineSetting -NoProxy -Confirm:$false -ErrorAction SilentlyContinue

if($Error[0])
{
    debug "FAILED to disable proxies. Error: $($Error[0].Exception.Message)"

    debug "Please also check CBEngineCurr.errlog (default location: C:\Program Files\Microsoft Azure Recovery Services Agent\Temp\CBEngineCurr.errlog) "

    debug "Disconnecting AzAccount..."

    Disconnect-AzAccount -Confirm:$false

    debug "AzAccount disconnected."

    debug "Exiting script with error code 2..."

    debug "------------------------------------------------------------------------------------------------------------------------------------------------"

    $Error.Clear()

    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force -Confirm:$false
    
    exit 2
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

    debug "Exiting script with error code 3..."

    debug "------------------------------------------------------------------------------------------------------------------------------------------------"

    $Error.Clear()

    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force -Confirm:$false
    
    exit 3
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

    debug "Exiting script with error code 4..."

    debug "------------------------------------------------------------------------------------------------------------------------------------------------"

    $Error.Clear()

    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force -Confirm:$false
    
    exit 4
}

debug "Files Backup Schedule applied successfully."

debug "Configuring Retention Policy..."

$FilesBackupRetentionPolicy = New-OBRetentionPolicy -RetentionDays $TargetFilesBackupRetentionDays

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

    debug "Exiting script with error code 5..."

    debug "------------------------------------------------------------------------------------------------------------------------------------------------"

    $Error.Clear()

    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force -Confirm:$false
    
    exit 5
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

    debug "Exiting script with error code 6..."

    debug "------------------------------------------------------------------------------------------------------------------------------------------------"

    $Error.Clear()

    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force -Confirm:$false
    
    exit 6
}

debug "Logical Disks info retrieved succesfully."

debug "Extracting Root Dirs for each disk..."

$DisksInfo = Get-Volume

$LogicalDiskRoots = @()

foreach($Disk in $DisksInfo)
{
    $driveLetter = $Disk.DriveLetter
    $FreeSpace = $Disk.SizeRemaining
    $FileSystemType = $Disk.FileSystemType

    if($FreeSpace -ge 0)
    {
        if($FileSystemType -eq "NTFS")
        {
            $DiskInfo = Get-PSDrive -PSProvider FileSystem -Name "$driveLetter" -ErrorAction SilentlyContinue
            
            $DiskInfoRoot = $DiskInfo.Root

            $LogicalDiskRoots = $LogicalDiskRoots + $DiskInfoRoot
        }
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

    debug "Exiting script with error code 7..."

    debug "------------------------------------------------------------------------------------------------------------------------------------------------"

    $Error.Clear()

    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force -Confirm:$false
    
    exit 7
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

    debug "Exiting script with error code 8..."

    debug "------------------------------------------------------------------------------------------------------------------------------------------------"

    $Error.Clear()

    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force -Confirm:$false
    
    exit 8
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

    debug "Exiting script with error code 9..."

    debug "------------------------------------------------------------------------------------------------------------------------------------------------"

    $Error.Clear()

    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force -Confirm:$false
    
    exit 9
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

    debug "Exiting script with error code 10..."

    debug "------------------------------------------------------------------------------------------------------------------------------------------------"

    $Error.Clear()

    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force -Confirm:$false
    
    exit 10
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

    debug "Exiting script with error code 11..."

    debug "------------------------------------------------------------------------------------------------------------------------------------------------"

    $Error.Clear()

    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force -Confirm:$false
    
    exit 11
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

    debug "Exiting script with error code 12..."

    debug "------------------------------------------------------------------------------------------------------------------------------------------------"

    $Error.Clear()

    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force -Confirm:$false
    
    exit 12
}

debug "System State Backup Policy applied Successfully."

debug "Script execution finished successfully. Exiting..."

Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force -Confirm:$false

exit 0