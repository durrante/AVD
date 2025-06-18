<#
.SYNOPSIS
    Azure Image Builder (AIB) Prerequisites Script

.DESCRIPTION
    This script prepares the necessary Azure resources for deploying Azure Image Builder (AIB).
    It includes:
        - Checks presence of and imports the Az PowerShell module
        - Logging into Azure and selecting a subscription
        - Creating a resource group
        - Registering required resource providers
        - Creating a storage account to host AIB software binaries with a private container
        - Creating a managed identity with appropriate roles and permissions
        - Creating an Azure Compute Gallery and image definition
        - (Optional) Configuration for setting up a dedicated virtual network for AIB

.NOTES
    Author    : Alex Durrant
    Version   : 1.0
    Date      : 23rd May 2025
    Contact   : Alex.Durrant@HybrIT.co.uk
    Usage     : Run this script in PowerShell 7 with the necessary owner permissions in the target Azure subscription.

.CHANGELOG
    1.0 - 23-05-2025 - Initial version by Alex Durrant
#>

param (
    [string]$ResourceGroupName = 'rg-aib-uks-002',
    [string]$Location = 'uksouth',
    [string]$CompanyID = 'AUD', # This is a three digit company identifier that will be used throughout the script.
    [hashtable]$Tags = @{
        "ApplicationName" = "AVD"
        "BusinessUnit"    = "Shared"
        "Environment"     = "Production"
        "Owner"           = "Alex@letsconfimgr.com"
    },
    [bool]$EnableNetworking = $false,

    [ValidatePattern('^\d{1,3}(\.\d{1,3}){3}/\d{1,2}$')]
    [string]$vNetAddressSpace = '172.16.0.0/16',

    [ValidatePattern('^\d{1,3}(\.\d{1,3}){3}/\d{1,2}$')]
    [string]$AIBSubnetAddressSpace = '172.16.100.0/24'
)

## Global variables, these may need changing to suit customer naming conventions, etc.
$GalleryName                = "acgproduks"
$imageDefName               = "imgd-win11avd-01"
$imageOfferName             = "Windows11Multi"
$imageSku                   = "M365Gen2"
$storageAccountName         = "st${CompanyID}aibuks001".ToLower()
$storageAccountSku          = "Standard_LRS"
$containerName              = "azureimagebuilder".ToLower()
$identityName               = "uami-aib-uks-01"
$vnetName                   = 'vnet-aib-uks-01' # if required, check EnableNetworking booleen
$subnetName                 = 'snet-aib-uks-01' # if required, check EnableNetworking booleen
$myRoleImageCreationUrl     = 'https://raw.githubusercontent.com/azure/azvmimagebuilder/master/solutions/12_Creating_AIB_Security_Roles/aibRoleImageCreation.json'
$myRoleImageCreationPath    = "myRoleImageCreation.json"
$sample_uri                 = "https://raw.githubusercontent.com/azure/azvmimagebuilder/master/solutions/12_Creating_AIB_Security_Roles/aibRoleNetworking.json"
$role_definition1           = "aibRoleNetworking1.json"
$role_definition2           = "aibRoleNetworking2.json"

## Display warning regarding variables
Write-Host "IMPORTANT: Please ensure all variable values in this script are correct before continuing." -ForegroundColor Yellow
Write-Host "To cancel and review variables, press Ctrl+C now." -ForegroundColor Yellow
Write-Host "To proceed, press ENTER..." -ForegroundColor Cyan
[void][System.Console]::ReadLine()

# Check PowerShell version
Write-Host "Checking PowerShell version, must be running at least PowerShell 7." -ForegroundColor Cyan
$psVer = $PSVersionTable.PSVersion
if ($psVer.Major -lt 7) {
    Write-Host "ERROR: PowerShell version $($psVer.Major).$($psVer.Minor).$($psVer.Build) detected." -ForegroundColor Red
    Write-Host "This script must be run in PowerShell 7 or higher." -ForegroundColor Red
    Write-Host "Please install the latest version from: https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows" -ForegroundColor Yellow
    exit 1
} else {
    Write-Host "PowerShell version is valid: $($psVer.Major).$($psVer.Minor).$($psVer.Build) ($($psVer.ToString()))" -ForegroundColor Green
}

# Check and Import Az PowerShell Module
Write-Host "Checking if Az PowerShell module is installed..." -ForegroundColor Cyan
$azModule = Get-InstalledModule -Name Az -ErrorAction SilentlyContinue
if (-not $azModule) {
    Write-Host "The 'Az' module is not installed." -ForegroundColor Red
    Write-Host "Please install it using the following command and re-run the script:" -ForegroundColor Yellow
    Write-Host "Install-Module -Name Az -Repository PSGallery -Force" -ForegroundColor Yellow
    exit 1
} else {
    Write-Host "Az module version $($azModule.Version) is installed." -ForegroundColor Green
    Write-Host "Please ensure the module is up to date by running: Update-Module -Name Az" -ForegroundColor Yellow
    if (-not (Get-Module -Name Az)) {
        Write-Host "Importing Az module into the session..." -ForegroundColor Cyan
        Import-Module -Name Az -Force
    }
}

if (!(Get-Module -Name Az)) {
    Write-Host "Importing Az module..." -ForegroundColor Yellow
    Import-Module -Name Az -Force
}

# Connect to Azure
Write-Host "Logging into Azure..." -ForegroundColor Cyan
Connect-AzAccount

# Select AZ subscription (Recommended to use dedicated AVD subscription)
Write-Host "Selecting Azure subscription..." -ForegroundColor Cyan
Get-AzSubscription | Out-GridView -PassThru | Select-AzSubscription

# AIB Resource group creation
Write-Host "Creating resource group if not exists..." -ForegroundColor Cyan
if (-not (Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue)) {
    New-AzResourceGroup -Name $ResourceGroupName -Location $Location -Tag:$Tags
} else {
    Write-Host "Resource group '$ResourceGroupName' already exists." -ForegroundColor Yellow
}

# Enabling Resource Providers
Write-Host "Registering required resource providers..." -ForegroundColor Cyan
$providerNamespaces = @(
    'Microsoft.Compute',
    'Microsoft.KeyVault',
    'Microsoft.Storage',
    'Microsoft.VirtualMachineImages',
    'Microsoft.Network',
    'Microsoft.ManagedIdentity',
    'Microsoft.ContainerInstance'
)

foreach ($providerNamespace in $providerNamespaces) {
    $resourceProvider = Get-AzResourceProvider -ProviderNamespace $providerNamespace
    if ($resourceProvider.RegistrationState -ne 'Registered') {
        Write-Host "Registering $providerNamespace..." -ForegroundColor Yellow
        Register-AzResourceProvider -ProviderNamespace $providerNamespace
    }
}

# ACG and Image Definition Creation
Write-Host "Creating Azure Compute Gallery and Image Definition..." -ForegroundColor Cyan
$GalleryParams = @{
    GalleryName         = $GalleryName
    ResourceGroupName   = $ResourceGroupName
    Location            = $Location
    Name                = $imageDefName
    OsState             = 'generalized'
    OsType              = 'Windows'
    Publisher           = $CompanyID
    Offer               = $imageOfferName
    Sku                 = $imageSku
    HyperVGeneration    = "V2"
    MinimumMemory       = 8
    MinimumVCPU         = 2
    DisallowedDiskType  = @("Standard_LRS")
    Feature = @(
        @{Name='SecurityType';Value='TrustedLaunch'},
        @{Name='DiskControllerTypes';Value='NVMe,SCSI'},
        @{Name='IsAcceleratedNetworkSupported';Value='True'},
        @{Name='IsHibernateSupported';Value='True'}
    )
}

if (-not (Get-AzGallery -ResourceGroupName $ResourceGroupName -Name $GalleryName -ErrorAction SilentlyContinue)) {
    New-AzGallery -GalleryName $GalleryName -ResourceGroupName $ResourceGroupName -Location $Location -Tag:$Tags
    Start-Sleep 60
}

if (-not (Get-AzGalleryImageDefinition -ResourceGroupName $ResourceGroupName -GalleryName $GalleryName -Name $imageDefName -ErrorAction SilentlyContinue)) {
    New-AzGalleryImageDefinition @GalleryParams -Tag:$Tags
}

# Creation of AIB storage account, software binaries and scripts will be housed here.
Write-Host "Creating Storage Account..." -ForegroundColor Cyan
if (-not (Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $storageAccountName -ErrorAction SilentlyContinue)) {
    New-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $storageAccountName -Location $Location -SkuName $storageAccountSku -EnableHttpsTrafficOnly $true -AllowBlobPublicAccess $true -MinimumTlsVersion TLS1_2 -Tag:$Tags
    Start-Sleep 60
}

$ctx = (Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $storageAccountName).Context
if (-not (Get-AzStorageContainer -Name $containerName -Context $ctx -ErrorAction SilentlyContinue)) {
    New-AzStorageContainer -Name $containerName -Context $ctx -Permission Off
}

## Create vNET for AIB (This step is only required when a dedicated vNet is required for AIB, most of the times it is not required, check with client.)
if ($EnableNetworking) {
Write-Host "Creating dedicated vNet for AIB..." -ForegroundColor Cyan

# Create NSG
Write-Host "Creating AIB vNet NSG..." -ForegroundColor Cyan
$networkSecurityGroup = New-AzNetworkSecurityGroup -ResourceGroupName $ResourceGroupName `
-Location $location -Name "nsg-$subnetname"

# Allow access from Proxy VM (aka load balancer) for private link via NSG
Write-Host "Updating NSG rule to allow access for AIB..." -ForegroundColor Cyan
Get-AzNetworkSecurityGroup -Name nsg-$subnetname -ResourceGroupName $ResourceGroupName  | Add-AzNetworkSecurityRuleConfig -Name AzureImageBuilderAccess -Description "Allow Image Builder Private Link Access to Proxy VM" -Access Allow -Protocol Tcp -Direction Inbound -Priority 400 -SourceAddressPrefix AzureLoadBalancer -SourcePortRange * -DestinationAddressPrefix VirtualNetwork -DestinationPortRange 60000-60001 | Set-AzNetworkSecurityGroup

# Create a subnet configuration
$subnetConfig = New-AzVirtualNetworkSubnetConfig -Name $subnetName -AddressPrefix $AIBSubnetAddressSpace -PrivateLinkServiceNetworkPoliciesFlag "Disabled" -NetworkSecurityGroup $networkSecurityGroup -ServiceEndpoint Microsoft.Storage

# Create a virtual network
Write-Host "Creating vNet and Subnet..." -ForegroundColor Cyan
New-AzVirtualNetwork -ResourceGroupName $resourceGroupName -Location $location `
    -Name $vnetName -AddressPrefix $vNetAddressSpace -Subnet $subnetConfig -Tag $tags

# Allow access from the previously created virtual network to storage account networking settings        
$subnet = Get-AzVirtualNetwork -ResourceGroupName $ResourceGroupName -Name $vnetName | Get-AzVirtualNetworkSubnetConfig -Name "$subnetName"
Add-AzStorageAccountNetworkRule -ResourceGroupName $ResourceGroupName -Name $storageAccountName -VirtualNetworkResourceId $subnet.Id

# Add current client external IP to Storage Firewall (Note: This is completely optional and may not be required)
$CurrentExternalIP = (Invoke-WebRequest -uri "http://ifconfig.me/ip").Content
Add-AzStorageAccountNetworkRule -ResourceGroupName $ResourceGroupName -Name $storageAccountName -IPAddressOrRange $CurrentExternalIP

# Set Storage Account Network Firewall to Deny (aka Enabled from selected networks and IP address as previously network rules have been defined)
Update-AzStorageAccountNetworkRuleSet -ResourceGroupName $resourceGroupName -Name $storageAccountName -DefaultAction Deny
} else {
    Write-Host "Networking setup skipped. Set -EnableNetworking \$true to enable vNet, NSG configuration and additional custom role creation." -ForegroundColor Yellow
}

# Creation of Managed Identity
Write-Host "Creating Managed Identity and assigning roles..." -ForegroundColor Cyan
$subscriptionID = (Get-AzContext).Subscription.Id
if (-not (Get-AzUserAssignedIdentity -ResourceGroupName $ResourceGroupName -Name $identityName -ErrorAction SilentlyContinue)) {
    New-AzUserAssignedIdentity -ResourceGroupName $ResourceGroupName -Name $identityName -Location $Location -Tag:$Tags
}
$identity = Get-AzUserAssignedIdentity -ResourceGroupName $ResourceGroupName -Name $identityName
$identityNameResourceId = $identity.Id
$identityNamePrincipalId = $identity.PrincipalId

## Create AIB Custom Roles
# AIBRoleIdentityName
$imageRoleDefName="[$CompanyID] Azure Image Builder Image Role"

# Your Azure Subscription ID
$subscriptionID = (Get-AzContext).Subscription.Id
Write-Output $subscriptionID

# Assign AIB Permissions to Managed Identity #1
# Download and Modify Permissions JSON for AIB Role

Invoke-WebRequest -Uri $myRoleImageCreationUrl -OutFile $myRoleImageCreationPath

$Content = Get-Content -Path $myRoleImageCreationPath -Raw
$Content = $Content -replace '<subscriptionID>', $subscriptionID
$Content = $Content -replace '<rgName>', $ResourceGroupName
$Content = $Content -replace 'Azure Image Builder Service Image Creation Role', $imageRoleDefName
$Content | Out-File -FilePath $myRoleImageCreationPath -Force

# Create the AIB Role Definition
New-AzRoleDefinition -InputFile $myRoleImageCreationPath -Verbose
Start-Sleep 60

# Assign the AIB Managed Identity to the AIB Definition (Note: if you receive an error of cannot find role definition, wait 30 seconds and try again.)
$RoleAssignParams = @{
    ObjectId = $identityNamePrincipalId
    RoleDefinitionName = $imageRoleDefName
    Scope = "/subscriptions/$subscriptionID/resourceGroups/$ResourceGroupName"
    }
    New-AzRoleAssignment @RoleAssignParams

if ($EnableNetworking) {
# Assign vNet permissions to Managed Identity for source network, this is only required if dedicated vNet is to be utilised
# Use a web request to download the sample JSON description
Invoke-WebRequest -Uri $sample_uri -Outfile $role_definition1

# Create a unique role name to avoid clashes in the same AAD domain
#$date = Get-Date -Format "dd-MM-yyyy"
$networkRoleDefName1="[$CompanyID] Azure Image Builder Service Networking Role Source"

# Update the JSON definition placeholders with variable values
((Get-Content -path $role_definition1 -Raw) -replace '<subscriptionID>',$subscriptionID) | Set-Content -Path $role_definition1
((Get-Content -path $role_definition1 -Raw) -replace '<vnetRgName>', $ResourceGroupName) | Set-Content -Path $role_definition1
((Get-Content -path $role_definition1 -Raw) -replace 'Azure Image Builder Service Networking Role',$networkRoleDefName1) | Set-Content -Path $role_definition1

# Create a custom role from the aibRoleNetworking.json description file
New-AzRoleDefinition -InputFile $role_definition1
Start-Sleep 60

# Assign the vNet custom role to the user-assigned managed identity for Azure Image Builder for source vNet
$parameters = @{
ObjectId = $identityNamePrincipalId
RoleDefinitionName = $networkRoleDefName1
Scope = '/subscriptions/' + $subscriptionID + '/resourceGroups/' + $ResourceGroupName
}

New-AzRoleAssignment @parameters


# Assign vNet permissions to Managed Identity for destination network, this is only required if dedicated vNet is to be utilised
# Use a web request to download the sample JSON description
Invoke-WebRequest -Uri $sample_uri -Outfile $role_definition2

# Create a unique role name to avoid clashes in the same AAD domain
#$date = Get-Date -Format "dd-MM-yyyy"
$networkRoleDefName2="[$CompanyID] Azure Image Builder Service Networking Role Destination"

# Update the JSON definition placeholders with variable values
((Get-Content -path $role_definition2 -Raw) -replace '<subscriptionID>',$subscriptionID) | Set-Content -Path $role_definition2
((Get-Content -path $role_definition2 -Raw) -replace '<vnetRgName>', $ResourceGroupName) | Set-Content -Path $role_definition2
((Get-Content -path $role_definition2 -Raw) -replace 'Azure Image Builder Service Networking Role',$networkRoleDefName2) | Set-Content -Path $role_definition2

# Create a custom role from the aibRoleNetworking.json description file
New-AzRoleDefinition -InputFile $role_definition2
Start-Sleep 60

# Assign the custom role to the user-assigned managed identity for Azure Image Builder for destination vNet
$parameters = @{
ObjectId = $identityNamePrincipalId
RoleDefinitionName = $networkRoleDefName2
Scope = '/subscriptions/' + $subscriptionID + '/resourceGroups/' + $ResourceGroupName
}

New-AzRoleAssignment @parameters
} else {
    Write-Host "Networking setup skipped. Set -EnableNetworking \$true to enable vNet, NSG configuration and additional custom role creation." -ForegroundColor Yellow
}

# Final permission configurations for Managed Identity
$storageAccountResourceId = (Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $storageAccountName).Id

# Assign 'Storage Blob Data Reader' role to the AIBIdentity for the storage account
New-AzRoleAssignment -ObjectId $identityNamePrincipalId -RoleDefinitionName 'Storage Blob Data Reader' -Scope $storageAccountResourceId -ErrorAction SilentlyContinue

# Assign 'Managed Identity Operator' role to the AIBIdentity at the subscription level
New-AzRoleAssignment -ObjectId $identityNamePrincipalId -RoleDefinitionName 'Managed Identity Operator' -Scope "/subscriptions/$subscriptionID" -ErrorAction SilentlyContinue

Write-Host "Azure Image Builder prerequisites completed successfully." -ForegroundColor Green
