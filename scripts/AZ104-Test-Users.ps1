# Use your verified domain
$tenantDomain = "johnnymeintelgmail.onmicrosoft.com"

Write-Host "Using domain: $tenantDomain" -ForegroundColor Green

# Set a secure password for all test users
$securePassword = ConvertTo-SecureString "ComplexPassword123!" -AsPlainText -Force

# Generate a unique identifier to avoid name conflicts
$uniqueId = Get-Random -Minimum 1000 -Maximum 9999

# Create test user for Network Monitor role
$networkUser = New-AzADUser -DisplayName "Network Monitor User" `
                           -UserPrincipalName "networkmonitor$uniqueId@$tenantDomain" `
                           -Password $securePassword `
                           -MailNickname "networkmonitor$uniqueId"

Write-Host "Created Network Monitor User with ID: $($networkUser.Id)" -ForegroundColor Green

# Create test user for Storage Contributor role
$storageUser = New-AzADUser -DisplayName "Storage Contributor User" `
                           -UserPrincipalName "storagecontributor$uniqueId@$tenantDomain" `
                           -Password $securePassword `
                           -MailNickname "storagecontributor$uniqueId"

Write-Host "Created Storage Contributor User with ID: $($storageUser.Id)" -ForegroundColor Green

# Create test user for DevSecOps Engineer role
$devSecOpsUser = New-AzADUser -DisplayName "DevSecOps Engineer User" `
                             -UserPrincipalName "devsecops$uniqueId@$tenantDomain" `
                             -Password $securePassword `
                             -MailNickname "devsecops$uniqueId"

Write-Host "Created DevSecOps Engineer User with ID: $($devSecOpsUser.Id)" -ForegroundColor Green

# Assign the Network Monitor role to the network user
New-AzRoleAssignment -ObjectId $networkUser.Id `
                    -RoleDefinitionName "Network Monitor" `
                    -ResourceGroupName "AZ104Practice"

Write-Host "Assigned Network Monitor role to networkmonitor$uniqueId@$tenantDomain" -ForegroundColor Cyan

# Assign the Storage Contributor role to the storage user
New-AzRoleAssignment -ObjectId $storageUser.Id `
                    -RoleDefinitionName "Storage Contributor" `
                    -ResourceGroupName "AZ104Practice"

Write-Host "Assigned Storage Contributor role to storagecontributor$uniqueId@$tenantDomain" -ForegroundColor Cyan

# Assign the DevSecOps Engineer role to the DevSecOps user
New-AzRoleAssignment -ObjectId $devSecOpsUser.Id `
                    -RoleDefinitionName "DevSecOps Engineer" `
                    -ResourceGroupName "AZ104Practice"

Write-Host "Assigned DevSecOps Engineer role to devsecops$uniqueId@$tenantDomain" -ForegroundColor Cyan

Write-Host "All users created and roles assigned successfully!" -ForegroundColor Green