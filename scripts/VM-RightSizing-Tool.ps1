# VM-RightSizing-Analysis.ps1
# An enhanced script for analyzing Azure VMs and recommending right-sized options
# Offers option to create new resource group or use existing one

# Connect to Azure if not already connected
if (-not (Get-AzContext)) {
    Connect-AzAccount
}

# Simple logging function
function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    # Output to console with color-coding
    switch ($Level) {
        "INFO" { Write-Host $logMessage -ForegroundColor Cyan }
        "WARNING" { Write-Host $logMessage -ForegroundColor Yellow }
        "ERROR" { Write-Host $logMessage -ForegroundColor Red }
    }
}

# Function to handle resource group selection or creation
function Get-ResourceGroup {
    Write-Host "`n=== Resource Group Selection ===" -ForegroundColor Green
    Write-Host "1. Use an existing resource group" -ForegroundColor White
    Write-Host "2. Create a new resource group" -ForegroundColor White
    
    $choice = Read-Host "Enter your choice (1 or 2)"
    
    if ($choice -eq "1") {
        # List existing resource groups
        Write-Log "Retrieving existing resource groups..."
        $resourceGroups = Get-AzResourceGroup | Sort-Object ResourceGroupName
        
        if ($resourceGroups.Count -eq 0) {
            Write-Log "No resource groups found. You need to create one." -Level "WARNING"
            return Get-ResourceGroup  # Recursively call to prompt for creation
        }
        
        Write-Host "`nAvailable Resource Groups:" -ForegroundColor Green
        for ($i = 0; $i -lt $resourceGroups.Count; $i++) {
            Write-Host "$($i+1). $($resourceGroups[$i].ResourceGroupName) (Location: $($resourceGroups[$i].Location))" -ForegroundColor White
        }
        
        $rgIndex = Read-Host "Enter the number of the resource group to use (1-$($resourceGroups.Count))"
        try {
            $index = [int]$rgIndex - 1
            if ($index -ge 0 -and $index -lt $resourceGroups.Count) {
                return $resourceGroups[$index].ResourceGroupName
            } else {
                Write-Log "Invalid selection. Please try again." -Level "ERROR"
                return Get-ResourceGroup  # Recursively call for valid input
            }
        } catch {
            Write-Log "Invalid input. Please enter a number." -Level "ERROR"
            return Get-ResourceGroup  # Recursively call for valid input
        }
    }
    elseif ($choice -eq "2") {
        # Create new resource group
        $rgName = Read-Host "Enter a name for the new resource group"
        
        # Get available locations and let user choose
        $locations = Get-AzLocation | Where-Object {$_.Providers -contains "Microsoft.Compute"} | Sort-Object DisplayName
        
        Write-Host "`nAvailable Locations:" -ForegroundColor Green
        for ($i = 0; $i -lt [Math]::Min(10, $locations.Count); $i++) {
            Write-Host "$($i+1). $($locations[$i].DisplayName) ($($locations[$i].Location))" -ForegroundColor White
        }
        
        $locationIndex = Read-Host "Enter the number of the location to use (1-10)"
        try {
            $index = [int]$locationIndex - 1
            if ($index -ge 0 -and $index -lt 10) {
                $location = $locations[$index].Location
                
                Write-Log "Creating resource group '$rgName' in location '$location'..."
                New-AzResourceGroup -Name $rgName -Location $location | Out-Null
                Write-Log "Resource group created successfully."
                
                return $rgName
            } else {
                Write-Log "Invalid selection. Please try again." -Level "ERROR"
                return Get-ResourceGroup  # Recursively call for valid input
            }
        } catch {
            Write-Log "Invalid input. Please enter a number." -Level "ERROR"
            return Get-ResourceGroup  # Recursively call for valid input
        }
    }
    else {
        Write-Log "Invalid choice. Please enter 1 or 2." -Level "ERROR"
        return Get-ResourceGroup  # Recursively call for valid input
    }
}

# Function to handle VM selection or creation
function Get-VirtualMachine {
    param (
        [string]$ResourceGroupName
    )
    
    Write-Host "`n=== Virtual Machine Selection ===" -ForegroundColor Green
    Write-Host "1. Use an existing VM in the resource group" -ForegroundColor White
    Write-Host "2. Create a new test VM" -ForegroundColor White
    
    $choice = Read-Host "Enter your choice (1 or 2)"
    
    if ($choice -eq "1") {
        # List existing VMs in the resource group
        Write-Log "Retrieving VMs in resource group '$ResourceGroupName'..."
        $vms = Get-AzVM -ResourceGroupName $ResourceGroupName | Sort-Object Name
        
        if ($vms.Count -eq 0) {
            Write-Log "No VMs found in this resource group. You need to create one." -Level "WARNING"
            return Get-VirtualMachine -ResourceGroupName $ResourceGroupName  # Recursively call to prompt for creation
        }
        
        Write-Host "`nAvailable Virtual Machines:" -ForegroundColor Green
        for ($i = 0; $i -lt $vms.Count; $i++) {
            Write-Host "$($i+1). $($vms[$i].Name) (Size: $($vms[$i].HardwareProfile.VmSize))" -ForegroundColor White
        }
        
        $vmIndex = Read-Host "Enter the number of the VM to analyze (1-$($vms.Count))"
        try {
            $index = [int]$vmIndex - 1
            if ($index -ge 0 -and $index -lt $vms.Count) {
                return $vms[$index].Name
            } else {
                Write-Log "Invalid selection. Please try again." -Level "ERROR"
                return Get-VirtualMachine -ResourceGroupName $ResourceGroupName  # Recursively call for valid input
            }
        } catch {
            Write-Log "Invalid input. Please enter a number." -Level "ERROR"
            return Get-VirtualMachine -ResourceGroupName $ResourceGroupName  # Recursively call for valid input
        }
    }
    elseif ($choice -eq "2") {
        # Create new VM with a name that meets Windows VM naming requirements (15 chars max)
        $vmName = "TestVM-" + (Get-Date -Format "MMddHHmm")
        
        # Ensure the name is not longer than 15 characters
        if ($vmName.Length -gt 15) {
            $vmName = "VM-" + (Get-Date -Format "MMddHHmm")
        }
        
        Write-Log "Creating a new test VM: $vmName"
        
        # VM size selection
        $vmSizes = @(
            "Standard_B1s",
            "Standard_B2s",
            "Standard_DS1_v2",
            "Standard_DS2_v2"
        )
        
        Write-Host "`nAvailable VM Sizes:" -ForegroundColor Green
        for ($i = 0; $i -lt $vmSizes.Count; $i++) {
            Write-Host "$($i+1). $($vmSizes[$i])" -ForegroundColor White
        }
        
        $sizeIndex = Read-Host "Enter the number of the VM size to use (1-$($vmSizes.Count))"
        try {
            $index = [int]$sizeIndex - 1
            if ($index -ge 0 -and $index -lt $vmSizes.Count) {
                $vmSize = $vmSizes[$index]
                
                # Set admin credentials
                $adminUsername = "azureadmin"
                $adminPassword = ConvertTo-SecureString "P@ssw0rd1234!" -AsPlainText -Force
                $credential = New-Object System.Management.Automation.PSCredential($adminUsername, $adminPassword)
                
                # Create VM
                Write-Log "Deploying VM. This may take a few minutes..."
                
                try {
                    New-AzVM -ResourceGroupName $ResourceGroupName `
                           -Name $vmName `
                           -Location (Get-AzResourceGroup -Name $ResourceGroupName).Location `
                           -Size $vmSize `
                           -Credential $credential `
                           -OpenPorts 3389 | Out-Null
                           
                    Write-Log "VM deployed successfully."
                    
                    # Add tags
                    try {
                        $vm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $vmName
                        
                        # Create new tags dictionary in the correct format
                        $tags = New-Object 'System.Collections.Generic.Dictionary[string,string]'
                        $tags.Add("Purpose", "RightSizingAnalysis")
                        $tags.Add("Environment", "Test")
                        $tags.Add("CreatedBy", "RightSizingTool")
                        
                        # Set the tags on the VM object
                        $vm.Tags = $tags
                        
                        # Update the VM
                        Update-AzVM -ResourceGroupName $ResourceGroupName -VM $vm | Out-Null
                        Write-Log "Tags added to VM successfully." -Level "SUCCESS"
                    }
                    catch {
                        Write-Log "Warning: Could not add tags to VM: $_" -Level "WARNING"
                        # Continue even if tags failed
                    }
                    
                    return $vmName
                }
                catch {
                    Write-Log "Error creating VM: $_" -Level "ERROR"
                    Write-Log "Please try again or select an existing VM." -Level "WARNING"
                    return Get-VirtualMachine -ResourceGroupName $ResourceGroupName
                }
            } else {
                Write-Log "Invalid selection. Please try again." -Level "ERROR"
                return Get-VirtualMachine -ResourceGroupName $ResourceGroupName
            }
        } catch {
            Write-Log "Invalid input. Please enter a number." -Level "ERROR"
            return Get-VirtualMachine -ResourceGroupName $ResourceGroupName
        }
    }
    else {
        Write-Log "Invalid choice. Please enter 1 or 2." -Level "ERROR"
        return Get-VirtualMachine -ResourceGroupName $ResourceGroupName
    }
}

# Function to analyze VM usage and recommend appropriate sizing
function Get-VMRightSizingRecommendation {
    param (
        [Parameter(Mandatory=$true)]
        [string]$ResourceGroupName,
        
        [Parameter(Mandatory=$true)]
        [string]$VMName
    )
    
    Write-Log "Analyzing VM: $VMName in resource group: $ResourceGroupName"
    
    # Get VM details
    $vm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName
    if (-not $vm) {
        Write-Log "VM not found: $VMName" -Level "ERROR"
        return $null
    }
    
    # Get current VM size
    $currentSize = $vm.HardwareProfile.VmSize
    Write-Log "Current VM size: $currentSize"
    
    # For demonstration purposes, we'll simulate metric collection
    # In a real scenario, you would use Azure Monitor metrics
    Write-Log "Collecting performance metrics (simulated for demonstration)"
    
    $cpuUtilization = Get-Random -Minimum 5 -Maximum 40
    $memoryUtilization = Get-Random -Minimum 10 -Maximum 60
    $diskIOPS = Get-Random -Minimum 100 -Maximum 500
    
    Write-Log "CPU Utilization: $cpuUtilization%"
    Write-Log "Memory Utilization: $memoryUtilization%"
    Write-Log "Disk IOPS: $diskIOPS"
    
    # Define VM size options (simplified for demonstration)
    $vmSizeTiers = @(
        @{Name="Standard_B1s"; CPUCores=1; MemoryGB=1; Cost=1},
        @{Name="Standard_B2s"; CPUCores=2; MemoryGB=4; Cost=2},
        @{Name="Standard_DS1_v2"; CPUCores=1; MemoryGB=3.5; Cost=3},
        @{Name="Standard_DS2_v2"; CPUCores=2; MemoryGB=7; Cost=4},
        @{Name="Standard_DS3_v2"; CPUCores=4; MemoryGB=14; Cost=5},
        @{Name="Standard_DS4_v2"; CPUCores=8; MemoryGB=28; Cost=6}
    )
    
    # Find current size in our tier list
    $currentSizeIndex = 0
    for ($i = 0; $i -lt $vmSizeTiers.Count; $i++) {
        if ($vmSizeTiers[$i].Name -eq $currentSize) {
            $currentSizeIndex = $i
            break
        }
    }
    
    # Determine recommended size based on utilization
    $recommendedSizeIndex = $currentSizeIndex
    $recommendation = "current size is appropriate"
    
    if ($cpuUtilization -lt 20 -and $memoryUtilization -lt 30) {
        # Underutilized - recommend downsizing if possible
        if ($currentSizeIndex -gt 0) {
            $recommendedSizeIndex = $currentSizeIndex - 1
            $recommendation = "downsizing (resource underutilization)"
        }
    }
    elseif ($cpuUtilization -gt 80 -or $memoryUtilization -gt 80) {
        # Overutilized - recommend upsizing
        if ($currentSizeIndex -lt ($vmSizeTiers.Count - 1)) {
            $recommendedSizeIndex = $currentSizeIndex + 1
            $recommendation = "upsizing (resource constraints)"
        }
    }
    
    $recommendedSize = $vmSizeTiers[$recommendedSizeIndex].Name
    
    # Calculate estimated monthly cost difference (simplified)
    $currentCost = $vmSizeTiers[$currentSizeIndex].Cost * 730  # 730 hours in a month
    $recommendedCost = $vmSizeTiers[$recommendedSizeIndex].Cost * 730
    $costDifference = $recommendedCost - $currentCost
    $costChangePercent = [math]::Round((($recommendedCost - $currentCost) / $currentCost) * 100, 1)
    
    # Format cost strings
    $costImpact = if ($costDifference -eq 0) {
        "No change"
    }
    elseif ($costDifference -gt 0) {
        "Increase of approximately $costChangePercent%"
    }
    else {
        "Decrease of approximately $($costChangePercent * -1)%"
    }
    
    # Create result object
    $result = [PSCustomObject]@{
        VMName = $VMName
        ResourceGroup = $ResourceGroupName
        CurrentSize = $currentSize
        RecommendedSize = $recommendedSize
        Recommendation = $recommendation
        CPUUtilization = "$cpuUtilization%"
        MemoryUtilization = "$memoryUtilization%"
        CostImpact = $costImpact
        CurrentSpecs = "$($vmSizeTiers[$currentSizeIndex].CPUCores) vCPUs, $($vmSizeTiers[$currentSizeIndex].MemoryGB) GB RAM"
        RecommendedSpecs = "$($vmSizeTiers[$recommendedSizeIndex].CPUCores) vCPUs, $($vmSizeTiers[$recommendedSizeIndex].MemoryGB) GB RAM"
        AnalysisDate = Get-Date -Format "yyyy-MM-dd HH:mm"
    }
    
    return $result
}

# Main execution flow
Write-Log "VM Right-Sizing Analysis Tool - Enhanced Version"
Write-Log "================================================"

# Get resource group (create new or use existing)
$resourceGroup = Get-ResourceGroup

# Get VM (create new or use existing)
$vmName = Get-VirtualMachine -ResourceGroupName $resourceGroup

# Wait a moment if VM was just created
if ($vmName -like "TestVM-*") {
    Write-Log "Waiting for VM initialization..."
    Start-Sleep -Seconds 20
}

# Run analysis
$analysis = Get-VMRightSizingRecommendation -ResourceGroupName $resourceGroup -VMName $vmName

if ($analysis) {
    # Display results
    Write-Host "`n==== Right-Sizing Analysis Results ====" -ForegroundColor Green
    $analysis | Format-List
    
    # Export results to CSV
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $csvPath = "VM-Sizing-$($vmName)-$timestamp.csv"
    $analysis | Export-Csv -Path $csvPath -NoTypeInformation
    Write-Log "Analysis results exported to: $csvPath"
    
    # Provide guidance on how to resize
    Write-Host "`n==== How to Implement This Recommendation ====" -ForegroundColor Green
    if ($analysis.CurrentSize -ne $analysis.RecommendedSize) {
        Write-Host "To resize the VM, use the following PowerShell commands:" -ForegroundColor Yellow
        Write-Host "# Step 1: Stop the VM (required for resizing)" -ForegroundColor White
        Write-Host "Stop-AzVM -ResourceGroupName $resourceGroup -Name $vmName -Force" -ForegroundColor White
        Write-Host "`n# Step 2: Update the VM size" -ForegroundColor White
        Write-Host "`$vm = Get-AzVM -ResourceGroupName $resourceGroup -Name $vmName" -ForegroundColor White
        Write-Host "`$vm.HardwareProfile.VmSize = '$($analysis.RecommendedSize)'" -ForegroundColor White
        Write-Host "Update-AzVM -ResourceGroupName $resourceGroup -VM `$vm" -ForegroundColor White
        Write-Host "`n# Step 3: Restart the VM" -ForegroundColor White
        Write-Host "Start-AzVM -ResourceGroupName $resourceGroup -Name $vmName" -ForegroundColor White
        Write-Host "`nNote: Resizing requires VM restart and may cause downtime." -ForegroundColor Yellow
    } else {
        Write-Host "The current VM size is optimal. No action needed." -ForegroundColor Green
    }
    
    # Ask if user wants to cleanup
    if ($vmName -like "TestVM-*") {
        Write-Host "`n==== Resource Cleanup ====" -ForegroundColor Green
        $cleanup = Read-Host "Would you like to delete the test VM to avoid ongoing charges? (y/n)"
        
        if ($cleanup -eq "y" -or $cleanup -eq "Y") {
            Write-Log "Cleaning up test VM..."
            Remove-AzVM -ResourceGroupName $resourceGroup -Name $vmName -Force
            Write-Log "VM deleted successfully."
        }
    }
}

Write-Log "Analysis complete. Thank you for using the VM Right-Sizing Tool."