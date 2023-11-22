<#
.SYNOPSIS
This script verifies the presence of the Azure Connected Machine Agent on the machine.
If the agent is absent, the script terminates. If present, it initiates a connection using the agent.
All operations executed by the script are documented in a designated log file.

.ERROR CODES

0 - success
1 - Error, Agent not installed
2 - Error, Agent not found in default installation directory at C:\Program Files\AzureConnectedMachineAgent
3 - Error, Registration with AzureArc failed (details in a separate log file created at the C:\Temp\Register_AzureArc

The script requires an input string for the subsequent Tags to be assigned in Azure Arc upon registration: 
Datacenter=<DC>,City=<CITY>,StateOrDistrict=<DISTRICT>,CountryOrRegion=<REGION>

.DESCRIPTION
Initially, the script inspects the registry to confirm the installation of the Azure Connected Machine Agent.
If the agent is missing, this detail is logged, and the script concludes with a status of 0.
Upon detecting the agent, the script configures the essential environment variables, sets the appropriate security protocol,
and then tries to establish a connection via the AzureConnectedMachineAgent. Any anomalies or issues during this phase
are captured, recorded, and relayed to a specific endpoint.

.NOTES
File Name      : RegisterACMA_V2.ps1
Last Updated   : Oct 11, 2023
Prerequisites  : Azure Connected Machine Agent should be present on the machine.

#>


param (
    [Parameter(Mandatory=$true)]
    [string]$AzureCloudEnv,
    [Parameter(Mandatory=$true)]
    [string]$TargetTennantID,
    [Parameter(Mandatory=$true)]
    [string]$TargetSubscriptionID,
    [Parameter(Mandatory=$true)]
    [string]$TargetCorrelationID,
    [Parameter(Mandatory=$true)]
    [string]$TargetAzureArcLocation,
    [Parameter(Mandatory=$true)]
    [string]$TargetResourceGroup,
    [Parameter(Mandatory=$true)]
    [string]$AuthorizationType,
    [Parameter(Mandatory=$true)]
    [string]$TargetServicePrincipalID,
    [Parameter(Mandatory=$true)]
    [string]$TargetServicePrincipalSecret,
    [Parameter(Mandatory=$false)]
    [string]$TargetMachineTags
)

# Capture script directory
$ScriptDir = $PSScriptRoot

# Define Azure Arc Agent EXE default path
$ArcAgentEXEDefaultPath = "$env:ProgramW6432\AzureConnectedMachineAgent\azcmagent.exe"

# Define log folder root
$LogFolderRoot = "C:\Temp"

# Define log folder path
$LogFolderPath = "C:\Temp\Register_AzureArc"

# Define the log file path
$logFilePath = "C:\Temp\Register_AzureArc\AzureArcRegistration_$(Get-Date -Format yyyy_MM_dd__HH).log"

# Define the Agent Error log file path
$ErrorlogFilePath = "C:\Temp\Register_AzureArc\azcmagent.exe_OutputLog_$(Get-Date -Format yyyy_MM_dd__HH).log" 

# Create Log Folder Root if it doesn't exist
if(!(Test-Path -Path $LogFolderRoot -PathType Container)) {
    New-Item -ItemType Directory -Force -Path $LogFolderRoot -Confirm:$false
}

# Create Log Folder Rooot if it doesn't exist
if(!(Test-Path -Path $LogFolderPath -PathType Container)) {
    New-Item -ItemType Directory -Force -Path $LogFolderPath -Confirm:$false
}

# Custom logging function
function debug($message) {
    $logMessage = "$(Get-Date -Format yyyy-MM-dd--HH-mm-ss) $message"
    Write-Host $logMessage
    Add-Content -Path $logFilePath -Value $logMessage -Force
}

debug "------------------------------------------------------------------------------------------------------------------------------------------------"

debug "Script initated."

debug "Working on executing machine. Name $env:COMPUTERNAME..."

debug "Checking if the Azure Connected Machine Agent is installed...."

# Check if Azure Connected Machine Agent is installed
$agentInstalled = Get-ChildItem -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" | 
                  Get-ItemProperty | 
                  Where-Object { $_.DisplayName -eq "Azure Connected Machine Agent" }

if (-not $agentInstalled) {

    debug "Azure Connected Machine Agent is NOT installed."

    debug "Exiting script with error code 1..."

    debug "------------------------------------------------------------------------------------------------------------------------------------------------"

    exit 1
}

Write-Host "Azure Connected Machine Agent is installed. Proceeding with the script."

debug "-----------------------------------------------------------------"
    
debug "Registration Parameters:"

debug "-----------------------------------------------------------------"

debug "Azure Cloud Type: $AzureCloudEnv"
debug "Target Tennant ID: $TargetTennantID"
debug "Target Subscription ID: $TargetSubscriptionID"
debug "Target Correlation ID: $TargetCorrelationID"
debug "Target Azure Arc region: $TargetAzureArcLocation"
debug "Target Resource Group: $TargetResourceGroup"
debug "Azure Authorization type: $AuthorizationType"
debug "Target Service Principal ID: $TargetServicePrincipalID"
debug "Target machine tags: $TargetMachineTags"

debug "-----------------------------------------------------------------"

debug "Checking if azcmagent.exe is located in the default InstallDir..."

$azcmagentLocationCheck = Test-Path -Path $ArcAgentEXEDefaultPath -PathType Leaf -ErrorAction SilentlyContinue

if($true -ne $azcmagentLocationCheck)
{
    debug "ERROR: Azure Arc agent isn't installed nor found at the default dir of $ArcAgentEXEDefaultPath."

    debug "Exiting with error code 2..."

    debug "------------------------------------------------------------------------------------------------------------------------------------------------"

    exit 2
}

debug "Azure Arc agent EXE was found at the default location of $ArcAgentEXEDefaultPath."

debug "Constructing cmdline arguments for passing to azcmagent.exe..."

$azcmagentCallArguments = "connect --service-principal-id '$TargetServicePrincipalID' --service-principal-secret '$TargetServicePrincipalSecret' --resource-group '$TargetResourceGroup' --tenant-id '$TargetTennantID' --location '$TargetAzureArcLocation' --subscription-id '$TargetSubscriptionID' --cloud '$AzureCloudEnv' --tags '$TargetMachineTags' --correlation-id '$TargetCorrelationID'"

$CallOperatorString = "$ArcAgentEXEDefaultPath" + " " + $azcmagentCallArguments

### Azure connected machine registration block below ########


    debug "Ensuring TLS1.2 is used when registering..."
    
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072;
    
    debug "Attempting to register the machine..."
    
    & "C:\Program Files\AzureConnectedMachineAgent\azcmagent.exe" connect --service-principal-id "$TargetServicePrincipalID" --service-principal-secret "$TargetServicePrincipalSecret" --resource-group "$TargetResourceGroup" --tenant-id "$TargetTennantID" --location "$TargetAzureArcLocation" --subscription-id "$TargetSubscriptionID" --cloud "$AzureCloudEnv" --tags "$TargetMachineTags" --correlation-id "$TargetCorrelationID" --verbose > $ErrorlogFilePath 2>&1;

if($LASTEXITCODE -ne 0)
{
    debug "-----------------------------------------------------------------"
    
    debug "FAILED to Register machine. ARC Agent exe Exit code: $LASTEXITCODE"

    debug "Please also check the error log file at $ErrorlogFilePath"

    debug "Please also check the error log file at $env:ProgramData\AzureConnectedMachineAgent\Log\azcmagent.log"

    debug "Exiting script with error code 3..."

    debug "-----------------------------------------------------------------"

    debug "------------------------------------------------------------------------------------------------------------------------------------------------"

    $Error.Clear()
    
    exit 3  
}


debug "Machine Registered Successfully."

debug "Script execution finished. Exiting..."

debug "------------------------------------------------------------------------------------------------------------------------------------------------"

exit 0