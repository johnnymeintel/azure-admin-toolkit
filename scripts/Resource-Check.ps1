# List-AzureInventory.ps1
# A quick script to list all Azure subscriptions, resource groups, and users

# Connect to Azure if not already connected
if (-not (Get-AzContext)) {
    Connect-AzAccount
}

# Create a timestamp for the output file
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$outputFile = "Azure-Inventory-$timestamp.txt"

# Output separator function
function Write-Separator {
    param (
        [string]$Title
    )
    
    $separator = "=" * 80
    $output = "`n$separator`n $Title `n$separator"
    Write-Host $output
    Add-Content -Path $outputFile -Value $output
}

# Start logging
"Azure Inventory Report - $(Get-Date)" | Out-File -FilePath $outputFile

# Get and display all subscriptions
Write-Separator "AZURE SUBSCRIPTIONS"
$subscriptions = Get-AzSubscription

foreach ($sub in $subscriptions) {
    $output = "Subscription: $($sub.Name)`nID: $($sub.Id)`nTenant: $($sub.TenantId)`n"
    Write-Host $output
    Add-Content -Path $outputFile -Value $output
}

# Get resource groups for each subscription
Write-Separator "RESOURCE GROUPS BY SUBSCRIPTION"

foreach ($sub in $subscriptions) {
    # Set the current subscription context
    Set-AzContext -Subscription $sub.Id | Out-Null
    
    $output = "`nSubscription: $($sub.Name)"
    Write-Host $output
    Add-Content -Path $outputFile -Value $output
    
    # Get all resource groups in the current subscription
    $resourceGroups = Get-AzResourceGroup
    
    if ($resourceGroups.Count -eq 0) {
        $output = "  No resource groups found"
        Write-Host $output
        Add-Content -Path $outputFile -Value $output
    }
    else {
        foreach ($rg in $resourceGroups) {
            $resourceCount = (Get-AzResource -ResourceGroupName $rg.ResourceGroupName).Count
            $output = "  • $($rg.ResourceGroupName) - Location: $($rg.Location) - Resources: $resourceCount"
            Write-Host $output
            Add-Content -Path $outputFile -Value $output
        }
    }
}

# Code to add to your script after the resource groups section
# This will list all resources in each resource group

Write-Separator "DETAILED RESOURCE INVENTORY"

foreach ($sub in $subscriptions) {
    # Set the current subscription context
    Set-AzContext -Subscription $sub.Id | Out-Null
    
    $output = "`nSubscription: $($sub.Name)"
    Write-Host $output
    Add-Content -Path $outputFile -Value $output
    
    # Get all resource groups in the current subscription
    $resourceGroups = Get-AzResourceGroup
    
    if ($resourceGroups.Count -eq 0) {
        $output = "  No resource groups found in this subscription"
        Write-Host $output
        Add-Content -Path $outputFile -Value $output
    }
    else {
        foreach ($rg in $resourceGroups) {
            $output = "`n  Resource Group: $($rg.ResourceGroupName) (Location: $($rg.Location))"
            Write-Host $output -ForegroundColor Green
            Add-Content -Path $outputFile -Value $output
            
            # Get all resources in this resource group
            $resources = Get-AzResource -ResourceGroupName $rg.ResourceGroupName
            
            if ($resources.Count -eq 0) {
                $output = "    No resources found in this resource group"
                Write-Host $output -ForegroundColor Yellow
                Add-Content -Path $outputFile -Value $output
            }
            else {
                # Group resources by type for better organization
                $resourcesByType = $resources | Group-Object -Property ResourceType
                
                foreach ($resourceType in $resourcesByType) {
                    $output = "    Resource Type: $($resourceType.Name) ($($resourceType.Count) resources)"
                    Write-Host $output -ForegroundColor Yellow
                    Add-Content -Path $outputFile -Value $output
                    
                    foreach ($resource in $resourceType.Group) {
                        # Get the SKU/size info if available
                        $skuInfo = ""
                        try {
                            if ($resource.ResourceType -eq "Microsoft.Compute/virtualMachines") {
                                $vm = Get-AzVM -ResourceGroupName $resource.ResourceGroupName -Name $resource.Name
                                $skuInfo = " (Size: $($vm.HardwareProfile.VmSize))"
                            }
                            elseif ($resource.ResourceType -eq "Microsoft.Storage/storageAccounts") {
                                $storage = Get-AzStorageAccount -ResourceGroupName $resource.ResourceGroupName -Name $resource.Name
                                $skuInfo = " (SKU: $($storage.Sku.Name), Kind: $($storage.Kind))"
                            }
                        }
                        catch {
                            # Silently continue if we can't get additional details
                        }
                        
                        # Get the creation time if available
                        $creationTime = ""
                        if ($resource.CreationTime) {
                            $creationTime = " [Created: $($resource.CreationTime.ToString('yyyy-MM-dd'))]"
                        }
                        
                        $output = "      • $($resource.Name)$skuInfo$creationTime"
                        $output += "`n        ID: $($resource.ResourceId)"
                        
                        # Add tags if they exist
                        if ($resource.Tags -and $resource.Tags.Count -gt 0) {
                            $output += "`n        Tags: "
                            foreach ($tag in $resource.Tags.GetEnumerator()) {
                                $output += "$($tag.Key)=$($tag.Value); "
                            }
                        }
                        
                        Write-Host $output
                        Add-Content -Path $outputFile -Value $output
                    }
                }
                
                # Calculate monthly cost estimate for the resource group (requires Cost Management module)
                # This is commented out by default as it requires additional permissions
                <#
                try {
                    $today = Get-Date
                    $startDate = $today.AddDays(-30).ToString("yyyy-MM-dd")
                    $endDate = $today.ToString("yyyy-MM-dd")
                    
                    $cost = Get-AzConsumptionUsageDetail -StartDate $startDate -EndDate $endDate -ResourceGroup $rg.ResourceGroupName | Measure-Object -Property PretaxCost -Sum
                    if ($cost.Sum -gt 0) {
                        $output = "    Estimated Monthly Cost: $($cost.Sum.ToString('C'))"
                        Write-Host $output -ForegroundColor Magenta
                        Add-Content -Path $outputFile -Value $output
                    }
                }
                catch {
                    # Skip cost retrieval if not available
                }
                #>
            }
        }
    }
}

# Update existing summary section by adding resource counts
$totalResources = 0
foreach ($sub in $subscriptions) {
    Set-AzContext -Subscription $sub.Id | Out-Null
    $totalResources += (Get-AzResource).Count
}

# Add this to your existing SUMMARY section
$output = "`nTotal Resources: $totalResources"
Write-Host $output
Add-Content -Path $outputFile -Value $output

# Get and display all Azure AD users
Write-Separator "AZURE AD USERS"

try {
    Write-Host "Retrieving Azure AD users..." -ForegroundColor Cyan
    $allUsers = Get-AzADUser -First 500 # Limiting to 500 users for performance
    
    if ($allUsers.Count -eq 0) {
        $output = "No Azure AD users found"
        Write-Host $output
        Add-Content -Path $outputFile -Value $output
    }
    else {
        $output = "Total Azure AD Users: $($allUsers.Count)"
        Write-Host $output
        Add-Content -Path $outputFile -Value $output
        
        # Display recently created users (last 30 days)
        $recentUsers = $allUsers | Where-Object { 
            $_.CreatedDateTime -and 
            [DateTime]$_.CreatedDateTime -gt (Get-Date).AddDays(-30) 
        } | Sort-Object CreatedDateTime -Descending
        
        if ($recentUsers.Count -gt 0) {
            $output = "`n--- Recently Created Users (Last 30 Days) ---"
            Write-Host $output -ForegroundColor Yellow
            Add-Content -Path $outputFile -Value $output
            
            foreach ($user in $recentUsers) {
                $createDate = if ($user.CreatedDateTime) { 
                    [DateTime]$user.CreatedDateTime 
                } else { 
                    "Unknown" 
                }
                
                $output = "  • $($user.DisplayName) ($($user.UserPrincipalName))"
                $output += "`n    Created: $createDate"
                $output += "`n    Object ID: $($user.Id)"
                $output += "`n    Account Type: $(if ($user.UserType) { $user.UserType } else { "Unknown" })"
                
                Write-Host $output
                Add-Content -Path $outputFile -Value $output
                Add-Content -Path $outputFile -Value ""
            }
        }
        
        # Group users by domain
        $output = "`n--- Users by Domain ---"
        Write-Host $output -ForegroundColor Yellow
        Add-Content -Path $outputFile -Value $output
        
        $domains = $allUsers | 
            Where-Object { $_.UserPrincipalName -match "@" } |
            Group-Object { ($_.UserPrincipalName -split "@")[1] } |
            Sort-Object Count -Descending
        
        foreach ($domain in $domains) {
            $output = "  • $($domain.Name): $($domain.Count) users"
            Write-Host $output
            Add-Content -Path $outputFile -Value $output
        }
        
        # Check for guest users
        $guestUsers = $allUsers | Where-Object { $_.UserType -eq "Guest" }
        if ($guestUsers.Count -gt 0) {
            $output = "`n--- Guest Users ($($guestUsers.Count) total) ---"
            Write-Host $output -ForegroundColor Yellow
            Add-Content -Path $outputFile -Value $output
            
            foreach ($guest in $guestUsers | Sort-Object DisplayName) {
                $output = "  • $($guest.DisplayName) ($($guest.UserPrincipalName))"
                Write-Host $output
                Add-Content -Path $outputFile -Value $output
            }
        }
        
        # List custom display name patterns (potential test users)
        $testPatterns = @("test", "demo", "monitor", "contributor", "devsecops")
        $potentialTestUsers = $allUsers | Where-Object { 
            $user = $_
            $matchFound = $false
            foreach ($pattern in $testPatterns) {
                if ($user.DisplayName -like "*$pattern*" -or $user.UserPrincipalName -like "*$pattern*") {
                    $matchFound = $true
                    break
                }
            }
            $matchFound
        }
        
        if ($potentialTestUsers.Count -gt 0) {
            $output = "`n--- Potential Test Users ($($potentialTestUsers.Count) total) ---"
            Write-Host $output -ForegroundColor Yellow
            Add-Content -Path $outputFile -Value $output
            
            foreach ($testUser in $potentialTestUsers | Sort-Object DisplayName) {
                $output = "  • $($testUser.DisplayName) ($($testUser.UserPrincipalName))"
                Write-Host $output
                Add-Content -Path $outputFile -Value $output
            }
        }
    }
}
catch {
    $output = "Error retrieving Azure AD users: $_"
    Write-Host $output -ForegroundColor Red
    Add-Content -Path $outputFile -Value $output
}

# Get user role assignments
Write-Separator "USER ROLE ASSIGNMENTS"

try {
    Write-Host "Retrieving role assignments..." -ForegroundColor Cyan
    
    # Get all role assignments
    $roleAssignments = Get-AzRoleAssignment | Where-Object { $_.ObjectType -eq "User" }
    
    if ($roleAssignments.Count -eq 0) {
        $output = "No user role assignments found"
        Write-Host $output
        Add-Content -Path $outputFile -Value $output
    }
    else {
        $output = "Total User Role Assignments: $($roleAssignments.Count)"
        Write-Host $output
        Add-Content -Path $outputFile -Value $output
        
        # Group by role definition
        $roleGroups = $roleAssignments | Group-Object RoleDefinitionName | Sort-Object Count -Descending
        
        $output = "`n--- Role Assignments by Role ---"
        Write-Host $output -ForegroundColor Yellow
        Add-Content -Path $outputFile -Value $output
        
        foreach ($role in $roleGroups) {
            $output = "  • $($role.Name): $($role.Count) assignments"
            Write-Host $output
            Add-Content -Path $outputFile -Value $output
        }
        
        # List all custom assignments (non-built-in roles)
        $customAssignments = $roleAssignments | Where-Object { 
            $_.RoleDefinitionName -notin @("Owner", "Contributor", "Reader", "User Access Administrator") 
        }
        
        if ($customAssignments.Count -gt 0) {
            $output = "`n--- Custom Role Assignments ---"
            Write-Host $output -ForegroundColor Yellow
            Add-Content -Path $outputFile -Value $output
            
            foreach ($assignment in $customAssignments) {
                if ($assignment.SignInName) {
                    $userInfo = $assignment.SignInName
                } else {
                    $user = $allUsers | Where-Object { $_.Id -eq $assignment.ObjectId } | Select-Object -First 1
                    $userInfo = if ($user) { "$($user.DisplayName) ($($user.UserPrincipalName))" } else { $assignment.ObjectId }
                }
                
                $output = "  • $userInfo"
                $output += "`n    Role: $($assignment.RoleDefinitionName)"
                $output += "`n    Scope: $($assignment.Scope)"
                
                Write-Host $output
                Add-Content -Path $outputFile -Value $output
                Add-Content -Path $outputFile -Value ""
            }
        }
    }
}
catch {
    $output = "Error retrieving role assignments: $_"
    Write-Host $output -ForegroundColor Red
    Add-Content -Path $outputFile -Value $output
}

# Display summary
$totalSubs = $subscriptions.Count
$totalRGs = (Get-AzResourceGroup).Count
$totalUsers = if ($allUsers) { $allUsers.Count } else { "Unknown" }
$totalRoleAssignments = if ($roleAssignments) { $roleAssignments.Count } else { "Unknown" }

Write-Separator "SUMMARY"
$output = "Total Subscriptions: $totalSubs"
$output += "`nTotal Resource Groups: $totalRGs"
$output += "`nTotal Azure AD Users: $totalUsers"
$output += "`nTotal User Role Assignments: $totalRoleAssignments"
Write-Host $output
Add-Content -Path $outputFile -Value $output

Write-Host "`nInventory saved to file: $outputFile" -ForegroundColor Green