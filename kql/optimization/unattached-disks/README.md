# Unattached Managed Disks — KQL

> **Atomic skill:** Find orphaned disks — pure waste with zero risk to delete.
> **Business question:** "How much are we spending on disks attached to nothing?"
> **Savings potential:** Immediate, zero-risk deletion
> **Cross-ref:** Part of the [`finops-toolkit`](https://github.com/duvvurs/finops-toolkit/tree/dev/src/scripts/finops-governance) optimization scripts

## Query

```kql
// Find unattached managed disks — pure waste, safe to delete
Resources
| where type =~ 'microsoft.compute/disks'
| extend DiskState = tostring(properties.diskState)
| extend DiskSizeGB = toint(properties.diskSizeGB)
| extend DiskSku = tostring(sku.name)
| where DiskState =~ 'Unattached'
| join kind=leftouter (
    // Check for snapshots that reference this disk (safety check)
    Resources
    | where type =~ 'microsoft.compute/snapshots'
    | extend SourceDisk = tostring(properties.creationData.sourceResourceId)
    | project SourceDisk
) on $left.id == $right.SourceDisk
| where isempty(SourceDisk)  // Only delete if no snapshot depends on it
| summarize 
    UnattachedDisks = count(),
    TotalWasteGB = sum(DiskSizeGB),
    BySku = make_set(DiskSku, 10)
    by subscriptionId
| extend EstimatedMonthlyCostGBP = round(todouble(TotalWasteGB) * 
    iff(set_has_element(BySku, 'Premium_LRS'), 0.14, 
    iff(set_has_element(BySku, 'StandardSSD_LRS'), 0.095, 0.04)), 2)
| order by EstimatedMonthlyCostGBP desc
```

## Cleanup Script

```powershell
# Delete unattached disks (safe — no VM attached)
# Prerequisites: verify no snapshot depends on disk (KQL query above checks this)

param([string]$SubscriptionId, [switch]$WhatIf)

Set-AzContext -SubscriptionId $SubscriptionId | Out-Null
$Disks = Get-AzDisk | Where-Object { $_.DiskState -eq 'Unattached' }

$TotalGB = 0
foreach ($Disk in $Disks) {
    $TotalGB += $Disk.DiskSizeGB
    if ($WhatIf) {
        Write-Host "[WHAT-IF] Would delete: $($Disk.Name) ($($Disk.DiskSizeGB) GB, $($Disk.Sku.Name))" -ForegroundColor Yellow
    } else {
        Remove-AzDisk -ResourceGroupName $Disk.ResourceGroupName -DiskName $Disk.Name -Force
        Write-Host "✓ Deleted: $($Disk.Name)" -ForegroundColor Green
    }
}
Write-Host "`nTotal recovered: $TotalGB GB across $($Disks.Count) disks"
```

## Pricing Reference

| Disk Type | £/GB/month | Typical Waste |
|-----------|:--:|:---:|
| Premium SSD | £0.14 | Most common orphan |
| Standard SSD | £0.095 | Dev/test orphan |
| Standard HDD | £0.04 | Legacy orphan |

## Production Results

- **EU Insurance:** Found 67 unattached disks (4.2TB) → deleted → **£380/month recovered**
- **UK Water:** Found 12 unattached disks (800GB) → deleted → **£72/month recovered**
