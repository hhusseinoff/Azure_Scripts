param(
    [Parameter(Mandatory=$true)]
    [string]$TargetVaultName
)

Remove-Item -Path "C:\Temp\ClearMARS_Certificates" -Recurse -Force -Confirm:$false -ErrorAction Ignore

# Capture script directory
$ScriptDir = $PSScriptRoot

# Define log folder root
$LogFolderRoot = "C:\Temp"

# Create folders if they don't exist
if(!(Test-Path -Path $LogFolderRoot)) {
    New-Item -ItemType Directory -Force -Path $LogFolderRoot
}

# Define log folder path
$LogFolderPath = "C:\Temp\ClearMARS_Certificates"

# Create folders if they don't exist
if(!(Test-Path -Path $LogFolderPath)) {
    New-Item -ItemType Directory -Force -Path $LogFolderPath
}

# Custom logging function
function debug($message) {
    $logMessage = "$(Get-Date -Format yyyy-MM-dd--HH-mm-ss) $message"
    Write-Host $logMessage
    Add-Content -Path "$LogFolderPath\ClearCertificates_$(Get-Date -Format yyyy_MM_dd__HH).log" -Value $logMessage -Force
}

debug "------------------------------------------------------------------------------------------------------------------------------------------------"

debug "Script initated."

debug "Looking for orphaned Azure Backup - personal certificates..."

$OrphanedVaultCertsSubject = "CN=$($TargetVaultName)*"

$OrphanedMachineCerts = Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object { $_.Subject -like 'CN=CB*' }

$OrphanedVaultCerts = Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object { $_.Subject -like $OrphanedVaultCertsSubject }

if($OrphanedMachineCerts)
{
    debug "Orphaned Azure Backup Certificates from previous successful registration found:"

    debug "-------------------------------------------------------------------------------"

    debug "Thumbprint`tExpiration`tSubject"

    debug "-------------------------------------------------------------------------------"

    foreach($Cert in $OrphanedMachineCerts)
    {
        $OrphanedCertThumbprint = $Cert.Thumbprint

        $OrphanedCertExpiry = $Cert.NotAfter

        $OrphanedCertSubject = $Cert.Subject
        
        debug "$OrphanedCertThumbprint`t$OrphanedCertExpiry`t$OrphanedCertSubject"
    }

    debug "-------------------------------------------------------------------------------"

    debug "Removing Orphaned Azure Backup Certificates from previous successful registrations..."

    foreach($Cert in $OrphanedMachineCerts)
    {
        $CertPSPath = $Cert.PSPath

        $OrphanedCertThumbprint = $Cert.Thumbprint

        Remove-Item -Path $CertPSPath -Force -Confirm:$false -ErrorAction SilentlyContinue

        $CertRemovedCheck = Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object { $_.Thumbprint -eq $OrphanedCertThumbprint }

        if($CertRemovedCheck)
        {
            debug "Failed to delete orphaned Cert with thumbprint $OrphanedCertThumbprint."

            debug "This will interfere with the machine registration, therefore exiting script...."

            debug "Disconnecting AzAccount..."

            Disconnect-AzAccount -Confirm:$false

            debug "AzAccount disconnected."

            debug "Exiting script with error code 4..."

            debug "------------------------------------------------------------------------------------------------------------------------------------------------"

            $Error.Clear()

            exit 4

        }
        else
        {
            debug "Orphaned Certificate with thumbprint $OrphanedCertThumbprint successfully deleted."

            continue
        }
    }
}

if($OrphanedVaultCerts)
{
    debug "Orphaned Azure Backup Certificates from previous registration attempts found:"

    debug "-------------------------------------------------------------------------------"

    debug "Thumbprint`tExpiration`tSubject"

    debug "-------------------------------------------------------------------------------"

    foreach ($Cert in $OrphanedVaultCerts)
    {
        $OrphanedCertThumbprint = $Cert.Thumbprint

        $OrphanedCertExpiry = $Cert.NotAfter

        $OrphanedCertSubject = $Cert.Subject
        
        debug "$OrphanedCertThumbprint`t$OrphanedCertExpiry`t$OrphanedCertSubject"
    }

    debug "-------------------------------------------------------------------------------"

    debug "Removing Orphaned Azure Backup Certificates from previous registration Attempts..."

    foreach($Cert in $OrphanedVaultCerts)
    {
        $CertPSPath = $Cert.PSPath

        $OrphanedCertThumbprint = $Cert.Thumbprint

        Remove-Item -Path $CertPSPath -Force -Confirm:$false -ErrorAction SilentlyContinue

        $CertRemovedCheck = Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object { $_.Thumbprint -eq $OrphanedCertThumbprint }

        if($CertRemovedCheck)
        {
            debug "Failed to delete orphaned Cert with thumbprint $OrphanedCertThumbprint."

            debug "This will interfere with the machine registration, therefore exiting script...."

            debug "Disconnecting AzAccount..."

            Disconnect-AzAccount -Confirm:$false

            debug "AzAccount disconnected."

            debug "Exiting script with error code 4..."

            debug "------------------------------------------------------------------------------------------------------------------------------------------------"

            $Error.Clear()

            exit 4

        }
        else
        {
            debug "Orphaned Certificate with thumbprint $OrphanedCertThumbprint successfully deleted."

            continue
        }
    }
}

debug "Script execution finished successfully. Exiting..."

exit 0