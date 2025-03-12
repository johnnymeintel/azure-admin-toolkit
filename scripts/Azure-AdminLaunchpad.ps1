# Azure-AdminLaunchpad.ps1
# Author: Johnny Meintel
# Date: March 2025
# Purpose: Setup and validate Azure administration environment for AZ-104 certification preparation
# Blog: https://johnnymeintel.com

#region MODULE VERIFICATION
# Check if the Azure PowerShell module is installed
# This is critical as all Azure automation depends on this module
if (!(Get-Module -ListAvailable Az)) {
    Write-Host "Azure PowerShell module not found. Installing Az module..." -ForegroundColor Yellow
    
    # Install the module for current user only - doesn't require admin rights
    # AllowClobber allows the cmdlet to overwrite existing commands
    Install-Module -Name Az -AllowClobber -Scope CurrentUser -Force
    
    Write-Host "Az module installed successfully!" -ForegroundColor Green
} else {
    Write-Host "Az PowerShell module is already installed." -ForegroundColor Green
    
    # Optionally check for updates to ensure you have the latest version
    $currentVersion = (Get-Module -ListAvailable Az).Version | Select-Object -First 1
    Write-Host "Current Az module version: $currentVersion" -ForegroundColor Cyan
}
#endregion

#region AUTHENTICATION
# Enhanced authentication with support for MFA and device code scenarios
try {
    Write-Host "Attempting to connect to Azure..." -ForegroundColor Cyan
    
    # First, try to get current context (in case already authenticated)
    $context = Get-AzContext
    
    # If not authenticated, try interactive authentication first
    if (!$context) {
        try {
            # Try standard interactive authentication
            Connect-AzAccount -ErrorAction Stop
            $context = Get-AzContext
        } catch {
            Write-Host "Standard authentication failed. This may be due to MFA requirements." -ForegroundColor Yellow
            Write-Host "Attempting to connect using device code authentication..." -ForegroundColor Cyan
            
            # Try device code authentication as fallback
            Connect-AzAccount -DeviceCode -ErrorAction Stop
            $context = Get-AzContext
        }
    } else {
        Write-Host "Already connected to Azure with existing context." -ForegroundColor Green
    }
    
    # Validate successful connection
    if ($context) {
        Write-Host "Successfully connected to Azure!" -ForegroundColor Green
        Write-Host "Connected to subscription: $($context.Subscription.Name) ($($context.Subscription.Id))" -ForegroundColor Green
        Write-Host "Connected as: $($context.Account.Id)" -ForegroundColor Green
        Write-Host "Tenant ID: $($context.Tenant.Id)" -ForegroundColor Green
    } else {
        throw "Failed to get Azure context after connection attempts."
    }
} catch {
    Write-Error "Failed to connect to Azure: $_"
    Write-Host "Suggestion: Try connecting manually first with 'Connect-AzAccount -DeviceCode' before running this script." -ForegroundColor Yellow
    exit 1
}
#endregion

#region DEFAULT CONFIGURATION
# Set default Azure region/location for resources
# WestUS2 is commonly used for its service availability and pricing
Write-Host "Setting default Azure region to WestUS2..." -ForegroundColor Cyan
# Set the default Azure location
$PSDefaultParameterValues['New-AzResourceGroup:Location'] = 'WestUS2'
$PSDefaultParameterValues['New-AzResource:Location'] = 'WestUS2'

# List all available subscriptions for reference
Write-Host "Available subscriptions:" -ForegroundColor Cyan
Get-AzSubscription | Format-Table Name, Id, TenantId, State -AutoSize

# Optional: Set a specific subscription if you have multiple
# Uncomment the following lines to use a specific subscription by name or ID
# $targetSubscription = "Your-Subscription-Name-or-ID"
# Select-AzSubscription -Subscription $targetSubscription
#endregion

#region RESOURCE GROUP CREATION
# Create a dedicated resource group for AZ-104 practice
# Using a consistent naming convention is an important best practice
# Isolating practice resources makes cleanup easier and prevents accidental deletion
try {
    $rgName = "AZ104-Practice-RG"
    $location = "WestUS2"
    
    # Check if the resource group already exists
    $existingRg = Get-AzResourceGroup -Name $rgName -ErrorAction SilentlyContinue
    
    if ($existingRg) {
        Write-Host "Resource group '$rgName' already exists." -ForegroundColor Yellow
    } else {
        Write-Host "Creating resource group '$rgName' in location '$location'..." -ForegroundColor Cyan
        New-AzResourceGroup -Name $rgName -Location $location -ErrorAction Stop
        Write-Host "Resource group created successfully!" -ForegroundColor Green
    }
} catch {
    Write-Error "Failed to create resource group: $_"
}
#endregion

#region TAGGING STRATEGY
# Create a basic tagging structure for resources
# Tags are crucial for organization, cost management, and governance
$tags = @{
    "Environment" = "Development"
    "Project" = "AZ104-Certification"
    "Owner" = "Johnny Meintel"
    "Department" = "IT"
    "CostCenter" = "Personal"
    "CreatedBy" = "AdminLaunchpadScript"
    "CreatedDate" = (Get-Date -Format "yyyy-MM-dd")
}

# Apply tags to the resource group
# Tags can be inherited by resources within the group but best practice is to set explicitly
try {
    Write-Host "Applying tags to resource group '$rgName'..." -ForegroundColor Cyan
    Set-AzResourceGroup -Name $rgName -Tag $tags -ErrorAction Stop
    Write-Host "Tags applied successfully!" -ForegroundColor Green
} catch {
    Write-Error "Failed to apply tags: $_"
}
#endregion

#region VALIDATION AND OUTPUT
# Output environment details for verification
# This provides a summary of the configured environment
Write-Host "`n====== Azure Environment Setup Summary ======" -ForegroundColor Cyan
Write-Host "Subscription: $($context.Subscription.Name) ($($context.Subscription.Id))"
Write-Host "Tenant ID: $($context.Tenant.Id)"
Write-Host "User: $($context.Account.Id)"
Write-Host "Default Location: $location"
Write-Host "Practice Resource Group: $rgName"

# List the tags that were applied
Write-Host "`nApplied Tags:" -ForegroundColor Cyan
$tags.GetEnumerator() | Format-Table Name, Value -AutoSize

# Optional: Validate resource group creation by retrieving properties
$rgDetails = Get-AzResourceGroup -Name $rgName
Write-Host "`nResource Group Properties:" -ForegroundColor Cyan
$rgDetails | Format-List ResourceGroupName, Location, ProvisioningState, Tags

Write-Host "`n====== Environment Setup Complete ======" -ForegroundColor Green
Write-Host "Your Azure administrator environment is ready for AZ-104 practice!"
Write-Host "Next steps: Deploy resources within your practice resource group."
#endregion

#region CLEANUP INSTRUCTIONS
<#
# CLEANUP INSTRUCTIONS (DO NOT RUN AUTOMATICALLY)
# To clean up resources when you're finished, run:
# Remove-AzResourceGroup -Name "AZ104-Practice-RG" -Force
#>
#endregion