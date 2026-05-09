// Daily burn rate by subscription
// Purpose: Track daily Azure spend per subscription to detect anomalies and trends
// Business question: "Which subscriptions are spending above baseline today?"
// Prerequisites: Cost Management export data or Cost Management connector

ResourceGraphQuery
| where type == "microsoft.resources/subscriptions"
| project subscriptionId, name
```

### Daily Burn Rate — Cost Management API Query

```kql
// Daily Azure spend across all subscriptions
// Uses Azure Cost Management REST API data exported to Log Analytics
// Replace with your actual table name from Cost Management export

AzureDiagnostics
| where Category == "CostManagement"
| summarize DailySpend = sum(Quantity * UnitPrice) by bin(TimeGenerated, 1d), SubscriptionId
| order by TimeGenerated desc
| extend MonthlyProjected = DailySpend * 30
| project TimeGenerated, SubscriptionId, DailySpend, MonthlyProjected
```

### Cost by Tag Dimension

```kql
// Cost allocation by tag — the foundation of showback/chargeback
// Business question: "How much does each cost centre / environment / workload spend?"
// Requires: Tagging compliance > 80% for meaningful allocation

Resources
| where isnotempty(tags)
| extend CostCentre = tostring(tags['cost-centre'])
| extend Environment = tostring(tags['environment'])
| extend Workload = tostring(tags['workload'])
| extend Department = tostring(tags['department'])
| where isnotempty(CostCentre)
| summarize ResourceCount = count() by CostCentre, Environment
| order by ResourceCount desc
| extend AllocationPct = todouble(ResourceCount) * 100.0 / toscalar(Resources | count)
```

### Subscription Cost Trend — Month over Month

```kql
// 6-month cost trend per subscription
// Business question: "Which subscriptions are trending up vs down?"
// Use case: Monthly FinOps review with stakeholders

Resources
| where type =~ 'microsoft.resources/subscriptions'
| project SubscriptionName = name, SubscriptionId = subscriptionId
| join kind=inner (
    ResourceChanges
    | where ChangeType == 'Create' or ChangeType == 'Update'
    | summarize Changes = count() by SubscriptionId = tolower(tostring(Properties.subscriptionId)), bin(TimeGenerated, 30d)
) on SubscriptionId
| order by TimeGenerated desc
```

### Top 10 Most Expensive Resource Types

```kql
// Identify which Azure resource types consume the most budget
// Business question: "Where should we focus optimization efforts?"
// Use case: Prioritize rightsizing initiatives

Resources
| summarize Count = count() by Type
| top 10 by Count desc
| extend Percentage = todouble(Count) * 100.0 / toscalar(Resources | count)
| project Type, Count, Percentage
| order by Count desc
```

### Cost Anomaly Detection Pattern

```kql
// Detect subscriptions with >20% spend increase vs previous period
// Business question: "Did anything spike unexpectedly this week?"
// Use case: Weekly FinOps anomaly review

// Pattern for use with Cost Management exported data
// Adjust threshold (0.20) based on your org's tolerance
let Threshold = 0.20;
let CurrentPeriod = 7d;
let PreviousPeriod = 14d;
// This is a template — adapt table/column names to your Cost Management export schema
// The pattern: compare current period average vs previous period average
// Flag anything exceeding Threshold
```

### Untagged Resources — Cost Exposure

```kql
// Find expensive resources without required tags
// Business question: "How much spend is unallocatable due to missing tags?"
// Use case: Tagging compliance reporting — drives accountability

Resources
| where isempty(tags['cost-centre']) or isempty(tags['environment'])
| where type !in (
    'microsoft.managedidentity/userassignedidentities',
    'microsoft.insights/actiongroups',
    'microsoft.insights/activitylogalerts'
) // Exclude resource types that typically don't need cost tags
| summarize 
    UntaggedCount = count(),
    Types = make_set(type, 50)
    by subscriptionId
| extend UntaggedPct = todouble(UntaggedCount) * 100.0 / toscalar(Resources | count)
| where UntaggedCount > 10
| order by UntaggedCount desc
| project subscriptionId, UntaggedCount, UntaggedPct, SampleTypes = slice(Types, 0, 5)
```

### Cross-Subscription Spend Comparison

```kql
// Compare resource distribution across subscriptions
// Business question: "Which subscriptions are over-provisioned relative to peers?"
// Use case: Rationalisation review for subscriptions with similar workloads

Resources
| summarize 
    TotalResources = count(),
    VMs = countif(type =~ 'microsoft.compute/virtualmachines'),
    StorageAccounts = countif(type =~ 'microsoft.storage/storageaccounts'),
    SQLServers = countif(type =~ 'microsoft.sql/servers'),
    AppServices = countif(type =~ 'microsoft.web/sites')
    by subscriptionId
| extend VMRatio = todouble(VMs) * 100.0 / toscalar(Resources | count)
| order by TotalResources desc
```
