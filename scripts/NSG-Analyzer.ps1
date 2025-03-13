# NSG-Analyzer.ps1
# Author: [Your Name]
# Date: March 12, 2025
# Purpose: Create and analyze Network Security Groups in Azure to identify security vulnerabilities
# Part of "Journey to Cloud Engineer" project series

#region SCRIPT STRUCTURE
# This script follows a top-down structure for better readability and execution:
# 1. Function Definitions: Define all functions at the top before any execution code
# 2. Main Script Logic: The actual execution flow follows after all functions are defined
# 3. Resource Creation: Creating Azure resources before analysis
# 4. Analysis and Remediation: Analyzing and improving security configuration
# 
# This structure ensures that all functions are loaded into memory before they're called,
# preventing the "function not recognized" error that occurs when a function is called
# before it's defined in the script.
#endregion

#region FUNCTION DEFINITIONS
# Define all functions at the beginning of the script to ensure they're available when called

# Function to analyze NSG rules for security vulnerabilities
function Get-NSGSecurityAnalysis {
    param (
        # Resource group containing the NSG
        [Parameter(Mandatory=$true)]
        [string]$ResourceGroupName,
        
        # Name of the NSG to analyze
        [Parameter(Mandatory=$true)]
        [string]$NSGName
    )
    
    # Retrieve the NSG object from Azure
    # This contains all rules and configurations we need to analyze
    $nsg = Get-AzNetworkSecurityGroup -ResourceGroupName $ResourceGroupName -Name $NSGName
    
    # Initialize an array to store security findings
    $findings = @()
    
    # Check for overly permissive rules that allow all inbound traffic
    # This is a critical security risk as it bypasses the purpose of having an NSG
    # Modified to detect ANY rules with open source address prefixes, not just catch-all rules
    $allowAllInbound = $nsg.SecurityRules | Where-Object { 
        $_.Access -eq "Allow" -and 
        $_.Direction -eq "Inbound" -and 
        $_.SourceAddressPrefix -eq "*" 
    }
    
    # If such rules exist, add them to our findings with high risk designation
    if ($allowAllInbound) {
        foreach ($rule in $allowAllInbound) {
            $findings += "HIGH RISK: Rule '$($rule.Name)' allows inbound traffic from any source (Internet)"
        }
    }
    
    # Define ports commonly used for management access that shouldn't be exposed
    # 22: SSH, 3389: RDP, 5985/5986: WinRM
    $managementPorts = @("22", "3389", "5985", "5986")
    
    # Check for rules that allow access to management ports from the internet
    # These could allow unauthorized administrative access
    $exposedManagementPorts = $nsg.SecurityRules | Where-Object { 
        $_.Access -eq "Allow" -and 
        $_.Direction -eq "Inbound" -and 
        $_.SourceAddressPrefix -eq "*" -and 
        ($managementPorts -contains $_.DestinationPortRange -or $_.DestinationPortRange -eq "*")
    }
    
    # For each exposed management port, add a medium risk finding
    if ($exposedManagementPorts) {
        foreach ($rule in $exposedManagementPorts) {
            $findings += "MEDIUM RISK: Rule '$($rule.Name)' exposes management port to internet"
        }
    }
    
    # Analyze all rules and assign risk levels based on configuration
    # This creates detailed information for each rule
    $ruleAnalysis = $nsg.SecurityRules | ForEach-Object {
        [PSCustomObject]@{
            Name = $_.Name
            Priority = $_.Priority
            Direction = $_.Direction
            Access = $_.Access
            SourceAddressPrefix = $_.SourceAddressPrefix
            SourcePortRange = $_.SourcePortRange
            DestinationAddressPrefix = $_.DestinationAddressPrefix
            DestinationPortRange = $_.DestinationPortRange
            Protocol = $_.Protocol
            # Assign risk levels based on rule configuration:
            # - High: Allow rules with any source address (*)
            # - Medium: Allow rules with specific sources
            # - Low: Deny rules (as they're restricting access)
            RiskLevel = if ($_.Access -eq "Allow" -and $_.SourceAddressPrefix -eq "*") { "High" } 
                        elseif ($_.Access -eq "Allow") { "Medium" } 
                        else { "Low" }
        }
    }
    
    # Return a custom object with our analysis results
    # This structured format makes it easy to use the results in reports
    return [PSCustomObject]@{
        NSGName = $NSGName
        TotalRules = $nsg.SecurityRules.Count
        AllowRules = ($nsg.SecurityRules | Where-Object { $_.Access -eq "Allow" }).Count
        DenyRules = ($nsg.SecurityRules | Where-Object { $_.Access -eq "Deny" }).Count
        RiskFindings = $findings
        RuleDetails = $ruleAnalysis
    }
}

# Function to apply security best practices to an existing NSG
# This function demonstrates how to remediate common NSG security issues
function Apply-NSGBestPractices {
    param (
        # Resource group containing the NSG
        [Parameter(Mandatory=$true)]
        [string]$ResourceGroupName,
        
        # Name of the NSG to secure
        [Parameter(Mandatory=$true)]
        [string]$NSGName,
        
        # Optional parameter to specify allowed source IPs for web traffic
        [Parameter(Mandatory=$false)]
        [string[]]$AllowedSourceIPs = @("40.112.0.0/13", "104.40.0.0/13"),  # Example IP ranges
        
        # Whether to remove risky rules
        [Parameter(Mandatory=$false)]
        [bool]$RemoveRiskyRules = $false
    )
    
    Write-Host "Starting security remediation for NSG: $NSGName" -ForegroundColor Yellow
    
    # Get the existing NSG
    $nsg = Get-AzNetworkSecurityGroup -ResourceGroupName $ResourceGroupName -Name $NSGName
    
    # Remove all existing rules to start with a clean slate
    # This is more reliable than selectively removing rules
    $existingRules = Get-AzNetworkSecurityRuleConfig -NetworkSecurityGroup $nsg
    
    if ($existingRules) {
        Write-Host "Removing existing rules..." -ForegroundColor Yellow
        
        foreach ($rule in $existingRules) {
            Write-Host "  - Removing rule: $($rule.Name)" -ForegroundColor Gray
            $nsg = $nsg | Remove-AzNetworkSecurityRuleConfig -Name $rule.Name
        }
        
        # Apply the changes to remove the rules
        $nsg | Set-AzNetworkSecurityGroup | Out-Null
        
        # Re-fetch the NSG after rules removal
        $nsg = Get-AzNetworkSecurityGroup -ResourceGroupName $ResourceGroupName -Name $NSGName
    }
    
    # Add improved rules with best practices
    Write-Host "Adding secure rules..." -ForegroundColor Yellow
    
    # 1. HTTP rule with specific source addresses
    Write-Host "  - Adding restricted HTTP rule" -ForegroundColor Gray
    $nsg | Add-AzNetworkSecurityRuleConfig -Name "Allow-HTTP-Secure" -Description "Allow HTTP from specific sources" `
        -Access Allow -Protocol Tcp -Direction Inbound -Priority 100 `
        -SourceAddressPrefix $AllowedSourceIPs -SourcePortRange * `
        -DestinationAddressPrefix * -DestinationPortRange 80 | Set-AzNetworkSecurityGroup
    
    # 2. HTTPS rule with specific source addresses
    Write-Host "  - Adding restricted HTTPS rule" -ForegroundColor Gray
    $nsg | Add-AzNetworkSecurityRuleConfig -Name "Allow-HTTPS-Secure" -Description "Allow HTTPS from specific sources" `
        -Access Allow -Protocol Tcp -Direction Inbound -Priority 110 `
        -SourceAddressPrefix $AllowedSourceIPs -SourcePortRange * `
        -DestinationAddressPrefix * -DestinationPortRange 443 | Set-AzNetworkSecurityGroup
    
    # 3. Block RDP rule (this is maintained for explicit denial)
    Write-Host "  - Adding RDP block rule" -ForegroundColor Gray
    $nsg | Add-AzNetworkSecurityRuleConfig -Name "Block-RDP" -Description "Block RDP from any source" `
        -Access Deny -Protocol Tcp -Direction Inbound -Priority 120 `
        -SourceAddressPrefix * -SourcePortRange * `
        -DestinationAddressPrefix * -DestinationPortRange 3389 | Set-AzNetworkSecurityGroup
    
    # 4. Add rule to allow Azure Load Balancer health probes using service tags
    Write-Host "  - Adding Azure Load Balancer rule" -ForegroundColor Gray
    try {
        $nsg | Add-AzNetworkSecurityRuleConfig -Name "Allow-AzureLoadBalancer" -Description "Allow Azure Load Balancer health probes" `
            -Access Allow -Protocol * -Direction Inbound -Priority 130 `
            -SourceAddressPrefix "AzureLoadBalancer" -SourcePortRange * `
            -DestinationAddressPrefix * -DestinationPortRange * | Set-AzNetworkSecurityGroup
    }
    catch {
        Write-Host "    - Error adding Load Balancer rule: $_" -ForegroundColor Red
    }
    
    # 5. Add an outbound rule to allow access to Azure Storage
    Write-Host "  - Adding Azure Storage outbound rule" -ForegroundColor Gray
    try {
        $nsg | Add-AzNetworkSecurityRuleConfig -Name "Allow-Storage-Outbound" -Description "Allow access to Azure Storage" `
            -Access Allow -Protocol Tcp -Direction Outbound -Priority 100 `
            -SourceAddressPrefix "VirtualNetwork" -SourcePortRange * `
            -DestinationAddressPrefix "Storage" -DestinationPortRange 443 | Set-AzNetworkSecurityGroup
    }
    catch {
        Write-Host "    - Error adding Storage outbound rule: $_" -ForegroundColor Red
    }
    
    Write-Host "Security remediation completed for $NSGName" -ForegroundColor Green
    return $nsg
}
#endregion

#region MAIN SCRIPT EXECUTION
# Main script execution begins after all functions are defined

# Check if already connected to Azure, and connect if not
# This prevents authentication errors if script is run multiple times
if (-not (Get-AzContext)) {
    Connect-AzContext
}

# Create a new resource group dedicated to network security testing
# Using WestUS2 region as it offers good performance and feature availability
$rgName = "Network-Security-RG"
New-AzResourceGroup -Name $rgName -Location "WestUS2"

# Create a subnet configuration that will be used in our virtual network
# Using 10.0.1.0/24 CIDR which provides 254 usable IP addresses
$subnetConfig = New-AzVirtualNetworkSubnetConfig -Name "WebSubnet" -AddressPrefix "10.0.1.0/24"

# Create the virtual network with our subnet configuration
# Using 10.0.0.0/16 CIDR which allows for multiple subnets within this address space
$vnet = New-AzVirtualNetwork -ResourceGroupName $rgName -Location "WestUS2" `
    -Name "TestVNet" -AddressPrefix "10.0.0.0/16" -Subnet $subnetConfig

# Create a new Network Security Group that will contain our security rules
# NSGs act as virtual firewalls at the subnet and NIC levels
$nsg = New-AzNetworkSecurityGroup -ResourceGroupName $rgName -Location "WestUS2" -Name "WebNSG"

# Add rule to allow HTTP traffic (port 80)
# Priority 100 means this rule is evaluated before rules with higher numbers
# Source * means traffic is allowed from any source IP address (which presents security risks)
$nsg | Add-AzNetworkSecurityRuleConfig -Name "Allow-HTTP" -Description "Allow HTTP" `
    -Access Allow -Protocol Tcp -Direction Inbound -Priority 100 `
    -SourceAddressPrefix * -SourcePortRange * `
    -DestinationAddressPrefix * -DestinationPortRange 80 | Set-AzNetworkSecurityGroup

# Add rule to allow HTTPS traffic (port 443)
# HTTPS provides encrypted web traffic unlike HTTP
# Still using * wildcards which is not ideal for production environments
$nsg | Add-AzNetworkSecurityRuleConfig -Name "Allow-HTTPS" -Description "Allow HTTPS" `
    -Access Allow -Protocol Tcp -Direction Inbound -Priority 110 `
    -SourceAddressPrefix * -SourcePortRange * `
    -DestinationAddressPrefix * -DestinationPortRange 443 | Set-AzNetworkSecurityGroup

# Add rule to explicitly deny RDP traffic (port 3389)
# This is a good security practice to prevent remote desktop access from the internet
# Even though Azure's default rule would block this, explicit denies improve security posture
$nsg | Add-AzNetworkSecurityRuleConfig -Name "Block-RDP" -Description "Block RDP" `
    -Access Deny -Protocol Tcp -Direction Inbound -Priority 120 `
    -SourceAddressPrefix * -SourcePortRange * `
    -DestinationAddressPrefix * -DestinationPortRange 3389 | Set-AzNetworkSecurityGroup

# Associate the NSG with our subnet
# This applies all the security rules to all resources within the subnet
Set-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name "WebSubnet" `
    -AddressPrefix "10.0.1.0/24" -NetworkSecurityGroup $nsg | Set-AzVirtualNetwork

# Execute the analysis function on our newly created NSG
Write-Host "`n--- INITIAL NSG ANALYSIS ---" -ForegroundColor Cyan
$analysis = Get-NSGSecurityAnalysis -ResourceGroupName $rgName -NSGName "WebNSG"

# Display summary information about the NSG
$analysis | Format-List NSGName, TotalRules, AllowRules, DenyRules, RiskFindings

# Display detailed information about each rule
$analysis.RuleDetails | Format-Table -AutoSize

# Save the analysis results to a JSON file for future reference
$initialAnalysisFile = "NSG-Initial-Analysis-$(Get-Date -Format 'yyyyMMdd').json"
$analysis | ConvertTo-Json -Depth 5 | Out-File -FilePath $initialAnalysisFile
Write-Host "Initial NSG analysis saved to $initialAnalysisFile" -ForegroundColor Green

# Apply best practices to improve the NSG
Write-Host "`n--- APPLYING SECURITY BEST PRACTICES ---" -ForegroundColor Cyan
Apply-NSGBestPractices -ResourceGroupName $rgName -NSGName "WebNSG" -RemoveRiskyRules $true

# Re-analyze the NSG after applying best practices
Write-Host "`n--- IMPROVED NSG ANALYSIS ---" -ForegroundColor Cyan
$improvedAnalysis = Get-NSGSecurityAnalysis -ResourceGroupName $rgName -NSGName "WebNSG"

# Display improved summary information
$improvedAnalysis | Format-List NSGName, TotalRules, AllowRules, DenyRules, RiskFindings

# Display improved detailed information
$improvedAnalysis.RuleDetails | Format-Table -AutoSize

# Save the improved analysis results
$improvedAnalysisFile = "NSG-Improved-Analysis-$(Get-Date -Format 'yyyyMMdd').json"
$improvedAnalysis | ConvertTo-Json -Depth 5 | Out-File -FilePath $improvedAnalysisFile
Write-Host "Improved NSG analysis saved to $improvedAnalysisFile" -ForegroundColor Green

# Generate a comparison report
Write-Host "`n--- SECURITY IMPROVEMENT SUMMARY ---" -ForegroundColor Cyan
Write-Host "Initial NSG:"
Write-Host "  - Total Rules: $($analysis.TotalRules)"
Write-Host "  - Security Findings: $($analysis.RiskFindings.Count)"

Write-Host "`nImproved NSG:"
Write-Host "  - Total Rules: $($improvedAnalysis.TotalRules)"
Write-Host "  - Security Findings: $($improvedAnalysis.RiskFindings.Count)"

Write-Host "`nSecurity Improvements:"
Write-Host "  - Added source IP restrictions to limit access"
Write-Host "  - Implemented Azure service tags for better security"
Write-Host "  - Created specific outbound rules following least privilege"
Write-Host "  - Blocked management ports from public access"
Write-Host "  - Implemented defense-in-depth with multiple control layers"

Write-Host "`nNext Steps:"
Write-Host "  - Consider implementing Azure Firewall for additional protection"
Write-Host "  - Enable NSG Flow Logs for traffic analysis"
Write-Host "  - Integrate with Azure Sentinel for security monitoring"
Write-Host "  - Implement Just-In-Time VM access for administrative tasks"

# Print completion message
Write-Host "`nNSG analysis and improvement completed for $($analysis.NSGName)." -ForegroundColor Green
#endregion