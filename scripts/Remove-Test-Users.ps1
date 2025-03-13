# Remove-TestUsers-Updated.ps1
# Script to remove test users created for Azure role assignment practice

# First, list all users to identify the ones we want to remove
Write-Host "Listing users with 'monitor', 'contributor', or 'devsecops' in their name..." -ForegroundColor Cyan
$testUsers = Get-AzADUser | Where-Object { 
    $_.DisplayName -like "*Monitor*" -or 
    $_.DisplayName -like "*Contributor*" -or 
    $_.DisplayName -like "*DevSecOps*" 
}

# Display the users that will be removed
if ($testUsers.Count -eq 0) {
    Write-Host "No matching test users found." -ForegroundColor Yellow
    exit
}

Write-Host "Found $($testUsers.Count) test users to remove:" -ForegroundColor Green
$testUsers | Format-Table DisplayName, UserPrincipalName, Id

# Ask for confirmation before proceeding
$confirmation = Read-Host "Are you sure you want to remove these users? (y/n)"
if ($confirmation -ne 'y') {
    Write-Host "Operation canceled." -ForegroundColor Yellow
    exit
}

# Now remove the users (without using the -Force parameter)
foreach ($user in $testUsers) {
    Write-Host "Removing user: $($user.DisplayName) ($($user.UserPrincipalName))" -ForegroundColor Cyan
    try {
        # Try without the -Force parameter
        Remove-AzADUser -ObjectId $user.Id
        Write-Host "  User removed successfully." -ForegroundColor Green
    }
    catch {
        Write-Host "  Failed to remove user: $_" -ForegroundColor Red
        Write-Host "  You may need to remove this user manually from the Azure portal." -ForegroundColor Yellow
    }
}

Write-Host "User cleanup completed." -ForegroundColor Green