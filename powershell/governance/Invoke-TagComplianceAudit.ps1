#Requires -Module Az.Resources, Az.Accounts
<#
.SYNOPSIS
    Audits tagging compliance and enforces required tags
    
.DESCRIPTION
    Production pattern for enterprise tagging governance.
    Phase 1: Audit — report compliance % per subscription
    Phase 2: Enforce — apply default tags where missing
    Phase 3: Notify — alert resource owners of non-compliance
    
.EXAMPLE
    .\Invoke-TagComplianceAudit.ps1 -SubscriptionIds @("sub1","sub2") -Mode Audit
    
.NOTES
    Author: Duvvur Sai Krishna
#>

param(
    [Parameter(Mandatory)]
    [string[]]$SubscriptionIds,
    
    [Parameter()]
    [ValidateSet('Audit', 'Enforce', 'Report')]
    [string]$Mode = 'Audit',
    
    [Parameter()]
    [hashtable]$RequiredTags = @{
        'cost-centre'        = ''
        'environment'        = ''
        'workload'           = ''
        'owner'              = ''
        'department'         = ''
        'data-classification' = ''
    }
)

$Results = @()

foreach ($SubId in $SubscriptionIds) {
    Write-Host "`n--- Subscription: $SubId ---" -ForegroundColor Cyan
    Select-AzContext -Name (Get-AzContext).Name -ErrorAction SilentlyContinue
    
    $Resources = Get-AzResource -DefaultProfile (Get-AzContext)
    $TotalCount = $Resources.Count
    $CompliantCount = 0
    $NonCompliant = @()
    
    foreach ($Resource in $Resources) {
        $MissingTags = @()
        
        foreach ($Tag in $RequiredTags.Keys) {
            if (-not $Resource.Tags -or -not $Resource.Tags.ContainsKey($Tag)) {
                $MissingTags += $Tag
            }
        }
        
        if ($MissingTags.Count -eq 0) {
            $CompliantCount++
        }
        else {
            $NonCompliant += [PSCustomObject]@{
                ResourceName = $Resource.Name
                ResourceType = $Resource.Type
                ResourceGroup = $Resource.ResourceGroupName
                MissingTags  = $MissingTags -join ', '
            }
            
            # Enforce mode: apply default tags
            if ($Mode -eq 'Enforce') {
                $TagsToAdd = @{}
                foreach ($Missing in $MissingTags) {
                    $TagsToAdd[$Missing] = if ($RequiredTags[$Missing]) { $RequiredTags[$Missing] } else { 'unknown' }
                }
                try {
                    Update-AzTag -ResourceId $Resource.ResourceId -Tag $TagsToAdd -Operation Merge
                    Write-Host "  ✓ Tagged: $($Resource.Name)" -ForegroundColor Green
                }
                catch {
                    Write-Warning "  ✗ Failed: $($Resource.Name) — $_"
                }
            }
        }
    }
    
    $CompliancePct = [math]::Round(($CompliantCount / $TotalCount) * 100, 1)
    
    $Results += [PSCustomObject]@{
        SubscriptionId  = $SubId
        TotalResources  = $TotalCount
        Compliant       = $CompliantCount
        NonCompliant    = $TotalCount - $CompliantCount
        CompliancePct   = $CompliancePct
    }
    
    Write-Host "  Compliance: $CompliancePct% ($CompliantCount/$TotalCount)" -ForegroundColor $(if ($CompliancePct -ge 90) { 'Green' } elseif ($CompliancePct -ge 70) { 'Yellow' } else { 'Red' })
}

# Summary report
if ($Mode -eq 'Report') {
    $Results | Format-Table -AutoSize
    $Results | Export-Csv -Path "tag-compliance-$(Get-Date -Format 'yyyy-MM-dd').csv" -NoTypeInformation
}
