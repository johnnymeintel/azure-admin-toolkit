# Azure-Cleanup.ps1
# A comprehensive cleanup script to reset your Azure environment
# CAUTION: This script will delete resources - use with care!

# Connect to Azure if not already connected
if (-not (Get-AzContext)) {
    Connect-AzAccount
}

# Set up logging
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$logFile = "Azure-Cleanup-Log-$timestamp.txt"

function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    # Color-code based on level
    switch ($Level) {
        "INFO" { Write-Host $logMessage -ForegroundColor Cyan }
        "WARNING" { Write-Host $logMessage -ForegroundColor Yellow }
        "ERROR" { Write-Host $logMessage -ForegroundColor Red }
        "SUCCESS" { Write-Host $logMessage -ForegroundColor Green }
    }
    
    # Write to log file
    Add-Content -Path $logFile -Value $logMessage
}

Write-Log "Azure Environment Cleanup Script - Starting" -Level "INFO"
Write-Log "CAUTION: This script will delete resources. Actions will be logged to: $logFile" -Level "WARNING"

# Identify current user to preserve
$currentContext = Get-AzContext
$currentUser = $currentContext.Account.Id
$currentSubscription = $currentContext.Subscription.Id
$currentSubscriptionName = $currentContext.Subscription.Name

Write-Log "Current user ($currentUser) and subscription ($currentSubscriptionName) will be preserved" -Level "INFO"

# Get confirmation before proceeding
Write-Host "`n" -NoNewline
Write-Host "===== CAUTION: DESTRUCTIVE OPERATION =====" -ForegroundColor Red
Write-Host "This script will DELETE resources from your Azure environment!" -ForegroundColor Red
Write-Host "The following will be removed:" -ForegroundColor Red
Write-Host " - All Resource Groups (except those you specify to preserve)" -ForegroundColor Red
Write-Host " - All Users (except the current user: $currentUser)" -ForegroundColor Red
Write-Host "`nThis operation cannot be undone!" -ForegroundColor Red
Write-Host "=====================================" -ForegroundColor Red
Write-Host "`n" -NoNewline

$confirmation = Read-Host "Type 'YES' (all capitals) to confirm you want to proceed"
if ($confirmation -ne "YES") {
    Write-Log "Operation canceled by user" -Level "WARNING"
    exit
}

# Ask for any resource groups to preserve
Write-Host "`nWould you like to preserve any specific resource groups? (y/n)" -ForegroundColor Yellow
$preserveRGs = Read-Host
$rgToPreserve = @()

if ($preserveRGs -eq "y") {
    Write-Host "Enter the names of resource groups to preserve, one per line." -ForegroundColor Yellow
    Write-Host "Press Enter on an empty line when done." -ForegroundColor Yellow
    
    while ($true) {
        $rgName = Read-Host
        if ([string]::IsNullOrWhiteSpace($rgName)) {
            break
        }
        $rgToPreserve += $rgName
        Write-Log "Resource Group to preserve: $rgName" -Level "INFO"
    }
}

# 1. Delete Resource Groups and Resources
Write-Log "Beginning Resource Group cleanup..." -Level "INFO"
$allResourceGroups = Get-AzResourceGroup

$resourceGroupsToDelete = $allResourceGroups | Where-Object { $rgToPreserve -notcontains $_.ResourceGroupName }

Write-Log "Found $($resourceGroupsToDelete.Count) resource group(s) to remove" -Level "INFO"

foreach ($rg in $resourceGroupsToDelete) {
    Write-Log "Removing Resource Group: $($rg.ResourceGroupName)" -Level "INFO"
    
    try {
        # -Force removes without confirmation, -AsJob runs in background
        Remove-AzResourceGroup -Name $rg.ResourceGroupName -Force -AsJob | Out-Null
        Write-Log "Resource Group deletion initiated: $($rg.ResourceGroupName)" -Level "INFO"
    }
    catch {
        Write-Log "Error removing Resource Group $($rg.ResourceGroupName): $_" -Level "ERROR"
    }
}

Write-Log "All Resource Group deletion jobs submitted. Waiting for completion..." -Level "INFO"

# Wait for all background jobs to complete
Get-Job | Wait-Job | Out-Null
Get-Job | Remove-Job -Force

Write-Log "Resource Group cleanup completed" -Level "SUCCESS"

# 2. Delete Azure AD Users (except current user)
Write-Log "Beginning Azure AD user cleanup..." -Level "INFO"

try {
    # Get all users (limiting to 1000 for performance)
    $allUsers = Get-AzADUser -First 1000
    
    # Extract the base email from the current user for comparison
    $currentUserEmail = ""
    if ($currentUser -match "([^@]+@[^@]+\.[^@]+)") {
        $currentUserEmail = $matches[1]
    }
    
    Write-Log "Current user email identified as: $currentUserEmail" -Level "INFO"
    
    # Filter out the current user (including external/guest representations) and other users to preserve
    $usersToDelete = $allUsers | Where-Object { 
        # Skip if it's exactly the current user
        if ($_.UserPrincipalName -eq $currentUser) {
            return $false
        }
        
        # Skip if it's an external representation of the current user (contains the email with _)
        if ($currentUserEmail -and 
            ($_.UserPrincipalName -like "*$($currentUserEmail.Replace('@', '_'))*" -or
             $_.UserPrincipalName -like "*$currentUserEmail*")) {
            return $false 
        }
        
        # Skip admin accounts
        if ($_.UserPrincipalName -like "*admin*") {
            return $false
        }
        
        # Skip if explicitly preserving guests
        if ($_.UserType -eq "Guest" -and $preserveGuests) {
            return $false
        }
        
        # Otherwise, include in deletion list
        return $true
    }
    
    Write-Log "Found $($usersToDelete.Count) user(s) to remove" -Level "INFO"
    
    # Ask for confirmation to delete specific users
    if ($usersToDelete.Count -gt 0) {
        Write-Host "`nThe following users will be deleted:" -ForegroundColor Yellow
        
        $i = 1
        foreach ($user in $usersToDelete) {
            Write-Host "$i. $($user.DisplayName) ($($user.UserPrincipalName))" -ForegroundColor White
            $i++
        }
        
        Write-Host "`nWould you like to proceed with deleting these users? (y/n)" -ForegroundColor Yellow
        $confirmUsers = Read-Host
        
        if ($confirmUsers -eq "y") {
            foreach ($user in $usersToDelete) {
                try {
                    Write-Log "Removing user: $($user.DisplayName) ($($user.UserPrincipalName))" -Level "INFO"
                    
                    # Try to remove role assignments first to avoid orphaned assignments
                    try {
                        $userRoleAssignments = Get-AzRoleAssignment -ObjectId $user.Id
                        
                        foreach ($assignment in $userRoleAssignments) {
                            Remove-AzRoleAssignment -ObjectId $user.Id -RoleDefinitionName $assignment.RoleDefinitionName -Scope $assignment.Scope
                            Write-Log "  Removed role assignment: $($assignment.RoleDefinitionName) on $($assignment.Scope)" -Level "INFO"
                        }
                    }
                    catch {
                        Write-Log "  Error removing role assignments: $_" -Level "WARNING"
                    }
                    
                    # Now remove the user
                    Remove-AzADUser -ObjectId $user.Id
                    Write-Log "  User removed successfully" -Level "SUCCESS"
                }
                catch {
                    Write-Log "  Error removing user: $_" -Level "ERROR"
                }
            }
        }
        else {
            Write-Log "User cleanup skipped by user choice" -Level "WARNING"
        }
    }
    else {
        Write-Log "No users found to delete" -Level "INFO"
    }
}
catch {
    Write-Log "Error during user cleanup: $_" -Level "ERROR"
}

# 3. Verify cleanup results
Write-Log "Verifying cleanup results..." -Level "INFO"

# Check remaining resource groups
$remainingRGs = Get-AzResourceGroup
Write-Log "Remaining Resource Groups: $($remainingRGs.Count)" -Level "INFO"
foreach ($rg in $remainingRGs) {
    Write-Log "  • $($rg.ResourceGroupName)" -Level "INFO"
}

# Check remaining users
try {
    $remainingUsers = Get-AzADUser -First 100
    Write-Log "Remaining Users: $($remainingUsers.Count)" -Level "INFO"
    foreach ($user in $remainingUsers) {
        Write-Log "  • $($user.DisplayName) ($($user.UserPrincipalName))" -Level "INFO"
    }
}
catch {
    Write-Log "Error checking remaining users: $_" -Level "ERROR"
}

Write-Log "Azure Environment Cleanup completed" -Level "SUCCESS"
Write-Host "`nCleanup log saved to: $logFile" -ForegroundColor Green