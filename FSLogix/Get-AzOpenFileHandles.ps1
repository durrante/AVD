<#
.SYNOPSIS
    Retrieves open file handles from an Azure File Share.

.DESCRIPTION
    This script connects to Azure, optionally allows the user to choose an Azure subscription,
    then retrieves and displays open file handles on a specified Azure Files share using the Az PowerShell module.

.PARAMETER ResourceGroupName
    The name of the Azure Resource Group containing the Storage Account.

.PARAMETER StorageAccountName
    The name of the Azure Storage Account.

.PARAMETER FileShareName
    The name of the Azure File Share to query.

.PARAMETER InteractiveSubscriptionSelect
    If set, a GUI will open allowing interactive subscription selection via Out-GridView.

.EXAMPLE
    .\Get-OpenFileHandles.ps1 -ResourceGroupName "rg-avd" -StorageAccountName "mystorage" -FileShareName "profiles"

.EXAMPLE
    .\Get-OpenFileHandles.ps1 -ResourceGroupName "rg-avd" -StorageAccountName "mystorage" -FileShareName "profiles" -InteractiveSubscriptionSelect

.NOTES
    Author:       Alex Durrant
    Version:      1.1.0
    Created:      16-06-2025
    Requirements: Az PowerShell Module, proper RBAC permissions to list storage file handles
#>

param (
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true)]
    [string]$StorageAccountName,

    [Parameter(Mandatory = $true)]
    [string]$FileShareName,

    [switch]$InteractiveSubscriptionSelect
)

function Get-OpenAzureFileHandles {
    try {
        # Login to Azure
        Write-Host "Connecting to Azure..." -ForegroundColor Cyan
        Connect-AzAccount -ErrorAction Stop

        # Optional: subscription selector
        if ($InteractiveSubscriptionSelect) {
            Write-Host "Select your Azure Subscription..." -ForegroundColor Yellow
            $subscription = Get-AzSubscription | Out-GridView -PassThru
            if (-not $subscription) {
                throw "No subscription selected. Exiting."
            }
            Select-AzSubscription -SubscriptionId $subscription.Id
        }

        # Get storage context
        Write-Host "Retrieving context for Storage Account '$StorageAccountName' in Resource Group '$ResourceGroupName'" -ForegroundColor Cyan
        $context = (Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -ErrorAction Stop).Context

        # Get open file handles
        Write-Host "Getting open file handles on share '$FileShareName'..." -ForegroundColor Green
        $fileHandles = Get-AzStorageFileHandle -Context $context -ShareName $FileShareName -Recursive -ErrorAction Stop

        if ($fileHandles) {
            $fileHandles | Format-Table Path, OpenTime, ClientIP, SessionId -AutoSize
        }
        else {
            Write-Host "No open file handles found." -ForegroundColor Green
        }
    }
    catch {
        Write-Error "Error: $_"
    }
}

# Execute function
Get-OpenAzureFileHandles
