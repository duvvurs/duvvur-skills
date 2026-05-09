# Right-Sizing Candidates — KQL

> **Atomic skill:** Identify over-provisioned VMs using CPU thresholds.
> **Business question:** "Which VMs are running oversized SKUs?"
> **Cross-ref:** [`rightsizing-assessment/`](../../../powershell/automation/rightsizing-assessment/) for the full PowerShell implementation

## Query

```kql
// Find VMs where the SKU is larger than needed based on CPU utilisation
// CPU avg < 15% and Max < 30% over 30 days = rightsize candidate
Resources
| where type =~ 'microsoft.compute/virtualmachines'
| extend CurrentSKU = tostring(properties.hardwareProfile.VmSize)
| extend SKUFamily = extract(@'(Standard_[A-Z]+)', 1, CurrentSKU)
| extend VMName = name
| join kind=inner (
    InsightsMetrics
    | where Name == "Percentage CPU"
    | where TimeGenerated > ago(30d)
    | summarize 
        AvgCPU = round(avg(Val), 1),
        MaxCPU = round(max(Val), 1),
        P95CPU = round(percentile(Val, 95), 1)
        by _ResourceId
) on $left.id == $right._ResourceId
| where AvgCPU < 15.0 and MaxCPU < 30.0
| where CurrentSKU !contains 'Basic' and CurrentSKU !contains '_B'  // Skip burstable
| extend Environment = iff(isnotempty(tags['environment']), tostring(tags['environment']), 'unknown')
| extend CostCentre = iff(isnotempty(tags['cost-centre']), tostring(tags['cost-centre']), 'untagged')
| project VMName, CurrentSKU, SKUFamily, AvgCPU, MaxCPU, P95CPU, Environment, CostCentre, resourceGroup, subscriptionId
| order by AvgCPU asc
```

## Downsize Recommendation Map

```kql
// Map current SKU to recommended smaller SKU
Resources
| where type =~ 'microsoft.compute/virtualmachines'
| extend SKU = tostring(properties.hardwareProfile.VmSize)
| extend Recommended = case(
    SKU == 'Standard_D4s_v5', 'Standard_D2s_v5 (save ~50%)',
    SKU == 'Standard_D8s_v5', 'Standard_D4s_v5 (save ~50%)',
    SKU == 'Standard_D16s_v5', 'Standard_D8s_v5 (save ~50%)',
    SKU == 'Standard_E4s_v5', 'Standard_E2s_v5 (save ~50%)',
    SKU == 'Standard_E8s_v5', 'Standard_E4s_v5 (save ~50%)',
    SKU == 'Standard_F4s_v2', 'Standard_F2s_v2 (save ~50%)',
    SKU == 'Standard_F8s_v2', 'Standard_F4s_v2 (save ~50%)',
    'Review manually'
)
| where Recommended != 'Review manually'
| summarize 
    VMs = count(),
    CurrentSKUs = make_set(SKU, 20),
    Recommendations = make_set(Recommended, 20)
    by subscriptionId
| order by VMs desc
```

## Decision Matrix

| Avg CPU | Max CPU | Action | Confidence |
|:---:|:---:|--------|:---:|
| < 5% | < 15% | Stop or delete | 🟢 Very High |
| < 10% | < 25% | Right-size down 2 tiers | 🟢 High |
| < 15% | < 30% | Right-size down 1 tier | 🟡 Medium |
| 15-25% | 30-50% | Monitor 14 more days | 🟡 Low |
| > 25% | > 50% | No action | ✅ Correctly sized |
