# Azure-RBAC-Auditor
# Author: Johnny Meintel
# Date: March 2025
# Purpose: PowerShell script that inventories all role assignments across a subscription or resource group.
# Blog: https://johnnymeintel.com

# Connect to Azure (comment out if already connected)
#Connect-AzAccount

# Parameters - modify as needed
$SubscriptionId = "d4e2e78f-2a06-4c3b-88c3-0e71b39dfc10" 
$ResourceGroupName = "AZ104Practice" # Set to $null to audit entire subscription
$OutputFile = "RBAC-Audit-$(Get-Date -Format 'yyyy-MM-dd').csv"

# Set context to the specified subscription
Set-AzContext -SubscriptionId $SubscriptionId

# Get role assignments
if ($ResourceGroupName) {
    Write-Host "Auditing RBAC assignments for resource group: $ResourceGroupName"
    $roleAssignments = Get-AzRoleAssignment -ResourceGroupName $ResourceGroupName
} else {
    Write-Host "Auditing RBAC assignments for the entire subscription"
    $roleAssignments = Get-AzRoleAssignment
}

# Process assignments and create detailed report
$reportData = @()
foreach ($role in $roleAssignments) {
    # Get object information
    $objectDetails = if ($role.ObjectType -eq "User") {
        Get-AzADUser -ObjectId $role.ObjectId
    } elseif ($role.ObjectType -eq "Group") {
        Get-AzADGroup -ObjectId $role.ObjectId
    } elseif ($role.ObjectType -eq "ServicePrincipal") {
        Get-AzADServicePrincipal -ObjectId $role.ObjectId
    } else {
        $null
    }
    
    # Create object for report
    $reportObject = [PSCustomObject]@{
        'PrincipalName' = $role.DisplayName
        'PrincipalType' = $role.ObjectType
        'PrincipalId' = $role.ObjectId
        'Role' = $role.RoleDefinitionName
        'IsCustomRole' = ($role.RoleDefinitionName -notin 'Owner','Contributor','Reader','User Access Administrator')
        'Scope' = $role.Scope
        'AssignmentId' = $role.RoleAssignmentId
        'CreatedOn' = $role.CreatedOn
        'Email' = if ($objectDetails.Mail) { $objectDetails.Mail } else { "N/A" }
    }
    
    $reportData += $reportObject
}

# Export to CSV
$reportData | Export-Csv -Path $OutputFile -NoTypeInformation

Write-Host "Audit complete. Report saved to: $OutputFile"

# Optional: Display summary statistics
$totalAssignments = $reportData.Count
$customRoleCount = ($reportData | Where-Object { $_.IsCustomRole -eq $true }).Count
$builtInRoleCount = $totalAssignments - $customRoleCount

Write-Host ""
Write-Host "Summary Statistics:"
Write-Host "-------------------"
Write-Host "Total Role Assignments: $totalAssignments"
Write-Host "Custom Role Assignments: $customRoleCount"
Write-Host "Built-in Role Assignments: $builtInRoleCount"

# Group by role for additional insights
$roleDistribution = $reportData | Group-Object -Property Role | Select-Object Name, Count | Sort-Object -Property Count -Descending

Write-Host ""
Write-Host "Role Distribution:"
Write-Host "----------------"
foreach ($role in $roleDistribution) {
    Write-Host "$($role.Name): $($role.Count) assignment(s)"
}