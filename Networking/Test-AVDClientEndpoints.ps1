<#
.SYNOPSIS
    Tests network connectivity to required Azure Virtual Desktop (AVD) endpoints from end-user devices.

.DESCRIPTION
    This script checks connectivity to the fully qualified domain names (FQDNs) listed in the Azure Virtual Desktop documentation. 
    It ensures end-user devices can connect to the necessary Azure services.

    NOTE: This script is provided "as-is" and is intended for indicative testing purposes only. 
    There are no warranties or guarantees of accuracy or completeness. It is the user's responsibility to verify 
    connectivity requirements and ensure proper configurations in their environment.

.PARAMETER EndpointList
    A list of FQDNs to test connectivity against, specific to Azure Virtual Desktop requirements.

.NOTES
    Author: Alex Durrant
    Version: V1.0 - 29/11/2024

    Make sure to run this script with sufficient permissions and network access to test connectivity.
    For complete and authoritative requirements, refer to the Azure Virtual Desktop documentation.

.LINK
    https://learn.microsoft.com/en-us/azure/virtual-desktop/required-fqdn-endpoint?tabs=azure#end-user-devices
#>
param (
    [string[]]$EndpointList = @(
        "login.microsoftonline.com",          # Authentication to Microsoft Online Services
        "rdbroker.wvd.microsoft.com",         # Service traffic (specific subdomain of *.wvd.microsoft.com)
        "rdweb.wvd.microsoft.com",            # Service traffic (specific subdomain of *.wvd.microsoft.com)
        "rddiagnostics.wvd.microsoft.com",    # Service traffic (specific subdomain of *.wvd.microsoft.com)
        "rdgateway.wvd.microsoft.com",        # Service traffic (specific subdomain of *.wvd.microsoft.com)
        "www.wvd.microsoft.com",              # Service traffic (specific subdomain of *.wvd.microsoft.com)
        "go.microsoft.com",                   # Microsoft FWLinks
        "aka.ms",                             # Microsoft URL shortener
        "learn.microsoft.com",                # Documentation
        "privacy.microsoft.com",              # Privacy statement
        "res.cdn.office.net",                 # Automatic updates for Windows Desktop
        "graph.microsoft.com",                # Service traffic
        "windows.cloud.microsoft",            # Connection center
        "windows365.microsoft.com",           # Service traffic
        "ecs.office.com"                      # Connection center
    )
)

function Test-AzureEndpoint {
    param (
        [string]$Endpoint
    )
    try {
        Write-Host "Testing connectivity to $Endpoint..." -ForegroundColor Cyan

        # Check if the endpoint is part of *.wvd.microsoft.com and display a warning
        if ($Endpoint -like "*.wvd.microsoft.com" -or $Endpoint -like "*wvd.microsoft.com") {
            Write-Warning "IMPORTANT: While testing $Endpoint, ensure that your network is configured to allow ALL subdomains under *.wvd.microsoft.com."
        }

        # Resolve FQDN to an IP
        $BaseEndpoint = $Endpoint -replace '^\*\.'    # Remove wildcard prefix if present
        $ResolvedIPs = [System.Net.Dns]::GetHostAddresses($BaseEndpoint) | Where-Object { $_.AddressFamily -eq 'InterNetwork' }

        if (-not $ResolvedIPs) {
            Write-Warning "Unable to resolve $Endpoint to an IP address."
            return
        }

        # Test connectivity to each resolved IP on port 443
        foreach ($IP in $ResolvedIPs) {
            $Connection = Test-NetConnection -ComputerName $IP.IPAddressToString -Port 443 -WarningAction SilentlyContinue
            if ($Connection.TcpTestSucceeded) {
                Write-Host "Connection to $Endpoint ($IP) on port 443 succeeded." -ForegroundColor Green
            } else {
                Write-Warning "Connection to $Endpoint ($IP) on port 443 failed."
            }
        }
    } catch {
        # Properly handle and format the error message
        Write-Error "An error occurred while testing ${Endpoint}: $($_.Exception.Message)"
    }
}

# Main script execution
Write-Host "Starting Azure Virtual Desktop Endpoint Connectivity Test..." -ForegroundColor Yellow
Write-Warning "IMPORTANT: Although this script tests specific subdomains, ensure your network allows ALL subdomains for wildcard domains like *.wvd.microsoft.com."

foreach ($Endpoint in $EndpointList) {
    Test-AzureEndpoint -Endpoint $Endpoint
}

Write-Host "Azure Virtual Desktop Endpoint Connectivity Test Complete." -ForegroundColor Yellow
