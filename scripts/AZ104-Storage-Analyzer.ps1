# StorageSecurity-Analyzer.ps1
# Author: Johnny Meintel
# Date: March 2025
# Purpose: Analyze storage account security configuration and provide actionable security recommendations
# Blog: https://johnnymeintel.com

# Check for existing Azure connection and prompt for login if needed
if (-not (Get-AzContext)) {
    Connect-AzAccount
}

# Define a resource group name for our test environment
$rg = "Storage-Test-RG"

# Create a new resource group in West US 2 region
New-AzResourceGroup -Name $rg -Location "WestUS2"

# Create first storage account with minimal security configuration
# Using splatting instead of backticks for better compatibility
$sa1Params = @{
    ResourceGroupName = $rg
    Name = "az104securestore$(Get-Random -Minimum 1000 -Maximum 9999)"
    Location = "WestUS2"
    SkuName = "Standard_LRS"
    Kind = "StorageV2"
}
$sa1 = New-AzStorageAccount @sa1Params

# Create second storage account with enhanced security features
$sa2Params = @{
    ResourceGroupName = $rg
    Name = "az104enhancedsec$(Get-Random -Minimum 1000 -Maximum 9999)"
    Location = "WestUS2"
    SkuName = "Standard_LRS"
    Kind = "StorageV2"
    MinimumTlsVersion = "TLS1_2"
    EnableHttpsTrafficOnly = $true
    AllowBlobPublicAccess = $false
}
$sa2 = New-AzStorageAccount @sa2Params

# Define a function to evaluate storage account security settings
function Get-StorageSecurityStatus {
    param (
        # Require a storage account object as input
        [Parameter(Mandatory=$true)]
        [Microsoft.Azure.Commands.Management.Storage.Models.PSStorageAccount]$StorageAccount
    )
    
    # Initialize security score and tracking variables
    $securityScore = 0
    $maxScore = 5
    $findings = @()
    
    # Check 1: HTTPS-only traffic enforcement
    if ($StorageAccount.EnableHttpsTrafficOnly) {
        $securityScore++
    } else {
        $findings += "HTTPS traffic only is not enforced"
    }
    
    # Check 2: TLS version validation
    if ($StorageAccount.MinimumTlsVersion -eq "TLS1_2") {
        $securityScore++
    } else {
        $findings += "TLS version is not set to 1.2"
    }
    
    # Check 3: Blob public access restriction
    if ($StorageAccount.AllowBlobPublicAccess -eq $false) {
        $securityScore++
    } else {
        $findings += "Blob public access is allowed"
    }
    
    # Check 4: Network access restrictions
    if ($StorageAccount.NetworkRuleSet.DefaultAction -eq "Deny") {
        $securityScore++
    } else {
        $findings += "Network access is not restricted"
    }
    
    # Check 5: Storage encryption verification
    if ($StorageAccount.Encryption.Services.Blob.Enabled) {
        $securityScore++
    } else {
        $findings += "Blob encryption is not enabled"
    }
    
    # Return a custom object with formatted results
    return [PSCustomObject]@{
        StorageAccountName = $StorageAccount.StorageAccountName
        SecurityScore = "$securityScore / $maxScore"
        ScorePercentage = [math]::Round(($securityScore / $maxScore) * 100, 0)
        Findings = $findings
    }
}

# Initialize array to store results from multiple storage accounts
$securityResults = @()

# Run security analysis on both storage accounts
$securityResults += Get-StorageSecurityStatus -StorageAccount $sa1
$securityResults += Get-StorageSecurityStatus -StorageAccount $sa2

# Display results in console as a formatted table
$securityResults | Format-Table -AutoSize

# Export results to a CSV file with timestamp in filename
$securityResults | Export-Csv -Path "StorageSecurity-Audit-$(Get-Date -Format 'yyyyMMdd').csv" -NoTypeInformation

# Output completion message with count of analyzed accounts
Write-Host "Storage security analysis completed for $($securityResults.Count) storage accounts." -ForegroundColor Green