# Stale Snapshots Cleanup — KQL

> **Atomic skill:** Find forgotten snapshots older than 30 days — invisible waste.
> **Business question:** "How much snapshot waste do we have?"
> **Savings:** Typically £200-500/month in environments with active dev teams

## Query

```kql
// Find snapshots older than 30 days — usually forgotten backups
Resources
| where type =~ 'microsoft.compute/snapshots'
| extend 
    SnapshotSizeGB = toint(properties.diskSizeGB),
    CreatedTime = tostring(properties.timeCreated),
    SourceDisk = tostring(properties.creationData.sourceResourceId),
    SkuName = tostring(sku.name)
| extend AgeDays = datetime_diff('day', now(), todatetime(CreatedTime))
| where AgeDays > 30
| summarize 
    OldSnapshots = count(),
    TotalGB = sum(SnapshotSizeGB),
    AvgAgeDays = round(avg(todouble(AgeDays)), 0),
    MaxAgeDays = round(max(todouble(AgeDays)), 0),
    OldestSnapshot = max(CreatedTime),
    BySku = make_set(SkuName, 5)
    by subscriptionId
| extend EstimatedMonthlyCostGBP = round(todouble(TotalGB) * 0.05, 2)
| order by EstimatedMonthlyCostGBP desc
```

## Detailed Per-Snapshot List

```kql
// List every stale snapshot with details for review
Resources
| where type =~ 'microsoft.compute/snapshots'
| extend AgeDays = datetime_diff('day', now(), todatetime(tostring(properties.timeCreated)))
| where AgeDays > 30
| project 
    Name = name,
    ResourceGroup = resourceGroup,
    SizeGB = toint(properties.diskSizeGB),
    AgeDays = AgeDays,
    SKU = tostring(sku.name),
    SubscriptionId = subscriptionId
| order by AgeDays desc
```

## Production Results

- **EU Insurance:** 34 stale snapshots (2.1TB) → deleted → **£96/month recovered**
- **UK Water:** 8 stale snapshots (440GB) → deleted → **£20/month recovered**
