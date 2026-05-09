# Tag Compliance Audit — KQL

> **Atomic skill:** Measure tagging compliance % across all subscriptions with per-tag breakdown.
> **Business question:** "What % of our resources have all required tags?"
> **Prerequisite for:** [`showback-chargeback/`](../../../cost-governance/showback-chargeback/shared-cost-allocation/)
> **Cross-ref:** [`tag-enforcement/`](../../../powershell/governance/tag-enforcement/) for automated remediation

## Query

```kql
// Full tagging compliance heatmap — which tags are missing where
Resources
| extend 
    HasCostCentre = isnotempty(tags['cost-centre']),
    HasEnvironment = isnotempty(tags['environment']),
    HasWorkload = isnotempty(tags['workload']),
    HasOwner = isnotempty(tags['owner']),
    HasDepartment = isnotempty(tags['department']),
    HasDataClassification = isnotempty(tags['data-classification'])
| extend 
    RequiredTags = 6,
    PresentTags = HasCostCentre + HasEnvironment + HasWorkload + HasOwner + HasDepartment + HasDataClassification
| extend CompliancePct = round(todouble(PresentTags) * 100.0 / RequiredTags, 1)
| summarize 
    TotalResources = count(),
    FullyCompliant = countif(CompliancePct == 100),
    PartiallyCompliant = countif(CompliancePct between (1 .. 99)),
    NonCompliant = countif(CompliancePct == 0),
    AvgCompliance = avg(CompliancePct),
    MissingCostCentre = countif(not(HasCostCentre)),
    MissingEnvironment = countif(not(HasEnvironment)),
    MissingWorkload = countif(not(HasWorkload)),
    MissingOwner = countif(not(HasOwner)),
    MissingDepartment = countif(not(HasDepartment)),
    MissingDataClassification = countif(not(HasDataClassification))
    by subscriptionId
| extend FullCompliancePct = round(todouble(FullyCompliant) * 100.0 / TotalResources, 1)
| order by AvgCompliance asc
```

## Per-Resource Detail (for remediation)

```kql
// List every non-compliant resource with which tags are missing
Resources
| where isempty(tags['cost-centre']) or isempty(tags['environment']) or isempty(tags['workload'])
| extend MissingTags = strcat_array(
    make_list_if('cost-centre', isempty(tags['cost-centre'])),
    make_list_if('environment', isempty(tags['environment'])),
    make_list_if('workload', isempty(tags['workload'])),
    make_list_if('owner', isempty(tags['owner'])),
    ', ')
| project name, type, resourceGroup, subscriptionId, MissingTags
| order by subscriptionId, resourceGroup
```

## Compliance Over Time (trend)

```kql
// Track compliance improvement week-over-week
// Run weekly and store results for trend analysis
Resources
| extend HasCostCentre = isnotempty(tags['cost-centre'])
| extend HasEnvironment = isnotempty(tags['environment'])
| extend HasWorkload = isnotempty(tags['workload'])
| summarize 
    Total = count(),
    CostCentrePct = round(countif(HasCostCentre) * 100.0 / count(), 1),
    EnvironmentPct = round(countif(HasEnvironment) * 100.0 / count(), 1),
    WorkloadPct = round(countif(HasWorkload) * 100.0 / count(), 1)
    by subscriptionId
| extend SnapshotDate = now()
```

## Production Evidence

| Phase | Duration | Compliance | Method |
|-------|----------|:---------:|--------|
| Week 1 (Audit) | Days 1-7 | 34% | Baseline measurement |
| Week 4 (Notify) | Days 22-28 | 58% | Email reports to resource owners |
| Week 8 (Inherit) | Days 50-56 | 82% | Auto-tag from RG via Azure Policy modify |
| Week 12 (Enforce) | Days 78-84 | 94% | Deny for new, modify for existing |
| Week 16 (Steady) | Day 112+ | 97% | Ongoing compliance via Policy |
