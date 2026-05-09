# Cost by Tag Dimension — KQL

> **Atomic skill:** Allocate costs by tag for showback/chargeback reporting.
> **Business question:** "How much does each cost centre / environment / workload spend?"
> **Prerequisite:** Tagging compliance > 80% (see [`tag-audit/`](../../governance-compliance/tag-audit/))
> **Cross-ref:** Feeds [`shared-cost-allocation/`](../../../cost-governance/showback-chargeback/shared-cost-allocation/)

## Query

```kql
// Cost allocation by tag dimensions — foundation of showback/chargeback
// Requires: tagging taxonomy deployed (see bicep/policies/tag-enforcement/)
Resources
| where isnotempty(tags)
| extend CostCentre = tostring(tags['cost-centre'])
| extend Environment = tostring(tags['environment'])
| extend Workload = tostring(tags['workload'])
| extend Department = tostring(tags['department'])
| extend DataClassification = tostring(tags['data-classification'])
| where isnotempty(CostCentre)
| summarize ResourceCount = count() by CostCentre, Environment, Department
| extend AllocationPct = round(todouble(ResourceCount) * 100.0 / toscalar(Resources | count), 2)
| order by ResourceCount desc
| extend Status = iff(AllocationPct < 5, '⚠️ Under-represented', '✅ Normal')
```

## Multi-Tag Pivot

```kql
// Pivot: cost allocation by environment × department matrix
Resources
| where isnotempty(tags['environment']) and isnotempty(tags['department'])
| summarize Count = count() by tostring(tags['environment']), tostring(tags['department'])
| evaluate pivot(tags_environment, sum(Count), tags_department)
| order by toint(Prod) desc
```

## Production Context

**Used for:** Monthly chargeback reconciliation, European insurance  
**Accuracy:** Direct allocation achieved 87% of total spend after 8-week tagging rollout  
**Unallocated:** 13% → split via shared cost model (see showback-chargeback/)  
**Consumer:** Finance team for department chargeback

## Tag → Power BI Flow

```mermaid
graph LR
    A[Tags on Resources] --> B[This KQL Query]
    B --> C[Cost Export CSV]
    C --> D[Power BI DimTag Table]
    D --> E[Showback Dashboard]
    E --> F[Chargeback Report]
    
    style A fill:#d97706,color:#fff
    style F fill:#059669,color:#fff
```
