# Tag Enforcement — PowerShell

> **Atomic skill:** Auto-enforce tags by inheriting from Resource Group level.
> **Cross-ref:** [`tag-audit/`](../../../kql/governance-compliance/tag-audit/) for compliance measurement, [`tag-enforcement/`](../../../bicep/policies/tag-enforcement/) for the policy version

## Script

```powershell
#Requires -Module Az.Resources, Az.Accounts

param(
    [Parameter(Mandatory)][string[]]$SubscriptionIds,
    [ValidateSet('Audit', 'Enforce', 'Report')][string]$Mode = 'Audit',
    [string[]]$RequiredTags = @('cost-centre', 'environment', 'workload', 'owner', 'department')
)

$Results = @()
foreach ($SubId in $SubscriptionIds) {
    Set-AzContext -SubscriptionId $SubId | Out-Null
    $Resources = Get-AzResource
    $RGs = Get-AzResourceGroup
    
    foreach ($Resource in $Resources) {
        $RG = $RGs | Where-Object { $_.ResourceGroupName -eq $Resource.ResourceGroupName }
        $MissingTags = @()
        
        foreach ($Tag in $RequiredTags) {
            $HasTag = $Resource.Tags -and $Resource.Tags.ContainsKey($Tag) -and $Resource.Tags[$Tag]
            if (-not $HasTag) {
                $MissingTags += $Tag
                
                if ($Mode -eq 'Enforce' -and $RG.Tags -and $RG.Tags.ContainsKey($Tag)) {
                    Update-AzTag -ResourceId $Resource.ResourceId `
                      -Tag @{ $Tag = $RG.Tags[$Tag] } -Operation Merge -ErrorAction SilentlyContinue
                }
            }
        }
        
        if ($MissingTags.Count -gt 0) {
            $Results += [PSCustomObject]@{
                Resource = $Resource.Name
                Type = $Resource.Type
                RG = $Resource.ResourceGroupName
                Missing = $MissingTags -join ', '
                RGHasTags = ($MissingTags | Where-Object { $RG.Tags.ContainsKey($_) }) -join ', '
                Sub = $SubId
            }
        }
    }
}

if ($Mode -eq 'Report') {
    $Results | Format-Table -AutoSize
    $Results | Export-Csv "tag-enforcement-$(Get-Date -Format 'yyyy-MM-dd').csv" -NoTypeInformation
}

$Total = (Get-AzResource).Count
$NonCompliant = $Results.Count
Write-Host "`n$NonCompliant / $Total resources non-compliant ($([math]::Round(($Total-$NonCompliant)/$Total*100,1))% compliance)" -ForegroundColor $(if(($Total-$NonCompliant)/$Total -gt 0.85){'Green'}else{'Yellow'})
```

## Enforcement Strategy

| Mode | What It Does | When to Use |
|------|-------------|-------------|
| `Audit` | Report only — no changes | Weeks 1-4 (baseline) |
| `Enforce` | Auto-tag from RG tags | Weeks 5-8 (close gaps) |
| `Report` | Export CSV for review | Every week (tracking) |
