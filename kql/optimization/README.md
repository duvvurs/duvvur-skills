// Idle VMs — No CPU activity for 14+ days
// Purpose: Find VMs that are running but doing nothing
// Business question: "Which VMs can we shut down or delete?"
// Savings potential: 20-40% of total compute spend in most environments
// Prerequisites: Azure Monitor VM insights or Log Analytics agent

// For use with Azure Monitor / Log Analytics
// Adapt workspace and table names to your environment
let ThresholdDays = 14;
let CpuThreshold = 5.0; // % — below this = idle
// Pattern: VMs with avg CPU < 5% for 14 consecutive days
// Action: Stop (immediate savings) or Delete (permanent savings)
// Always verify with workload owner before actioning
```

### Idle Managed Disks

```kql
// Find unattached managed disks — pure waste
// Business question: "How much are we spending on disks attached to nothing?"
// Action: Delete immediately (no risk — not attached to any VM)

Resources
| where type =~ 'microsoft.compute/disks'
| extend DiskState = tostring(properties.diskState)
| extend DiskSizeGB = toint(properties.diskSizeGB)
| where DiskState =~ 'Unattached'
| summarize 
    UnattachedDisks = count(),
    TotalWasteGB = sum(DiskSizeGB)
    by subscriptionId
| extend EstimatedMonthlyCostUSD = todouble(TotalWasteGB) * 0.05 // Approx £0.04/GB/month for Standard SSD
| order by EstimatedMonthlyCostUSD desc
```

### Right-Sizing Candidates — Oversized VMs

```kql
// Find VMs where the SKU is larger than needed
// Business question: "Which VMs are over-provisioned?"
// Methodology: CPU avg < 15% and Max < 30% over 30 days = rightsize candidate
// Action: Recommend smaller SKU from same family

Resources
| where type =~ 'microsoft.compute/virtualmachines'
| extend 
    CurrentSKU = tostring(properties.hardwareProfile.vmSize),
    OSDiskSize = tostring(properties.storageProfile.osDisk.diskSizeGB),
    DataDiskCount = array_length(properties.storageProfile.dataDisks)
| extend SKUFamily = extract(@"(Standard_[A-Z]+)", 1, CurrentSKU)
| summarize 
    VMCount = count(),
    SampleSKUs = make_set(CurrentSKU, 20)
    by SKUFamily, subscriptionId
| order by VMCount desc
```

### Public IPs Without Association — Wasted Spend

```kql
// Public IPs that aren't attached to any resource
// Business question: "How much are we wasting on unused public IPs?"
// Action: Delete — immediate savings, no risk

Resources
| where type =~ 'microsoft.network/publicipaddresses'
| extend IPConfig = tostring(properties.ipConfiguration)
| where isempty(IPConfig) or IPConfig == ''
| extend SKUName = tostring(properties.publicIPAllocationMethod)
| extend IPAddress = tostring(properties.ipAddress)
| where isnotempty(IPAddress)
| summarize 
    UnusedPublicIPs = count(),
    IPs = make_set(IPAddress, 20)
    by subscriptionId
| order by UnusedPublicIPs desc
```

### Storage Account Lifecycle — Old Blob Data

```kql
// Find storage accounts with data that should move to Cool/Archive tier
// Business question: "How much hot storage can we tier down?"
// Savings: Hot → Cool = ~40% savings, Hot → Archive = ~80% savings

Resources
| where type =~ 'microsoft.storage/storageaccounts'
| extend 
    AccessTier = tostring(properties.accessTier),
    Kind = tostring(properties.kind),
    CreationTime = tostring(properties.creationTime)
| where AccessTier =~ 'Hot'
| extend AgeDays = datetime_diff('day', now(), todatetime(CreationTime))
| where AgeDays > 180
| summarize 
    HotStorageCount = count(),
    AvgAgeDays = avg(todouble(AgeDays))
    by subscriptionId
| order by HotStorageCount desc
```

### Old Snapshots — Cleanup Candidates

```kql
// Find snapshots older than 30 days — usually forgotten backups
// Business question: "How much snapshot waste do we have?"
// Action: Review and delete (snapshots are charged per GB)

Resources
| where type =~ 'microsoft.compute/snapshots'
| extend 
    SnapshotSizeGB = toint(properties.diskSizeGB),
    CreatedTime = tostring(properties.timeCreated)
| extend AgeDays = datetime_diff('day', now(), todatetime(CreatedTime))
| where AgeDays > 30
| summarize 
    OldSnapshots = count(),
    TotalGB = sum(SnapshotSizeGB),
    AvgAgeDays = avg(todouble(AgeDays))
    by subscriptionId
| extend EstimatedMonthlyCostUSD = todouble(TotalGB) * 0.05
| order by EstimatedMonthlyCostUSD desc
```

### App Service Plan Over-Provisioning

```kql
// Find App Service Plans running on expensive tiers with low utilization
// Business question: "Which App Service Plans can be consolidated or downgraded?"

Resources
| where type =~ 'microsoft.web/serverfarms'
| extend 
    SKUName = tostring(sku.name),
    SKUTier = tostring(sku.tier),
    WorkerCount = toint(properties.numberOfWorkers),
    MaximumInstances = toint(properties.maximumNumberOfWorkers)
| extend UtilizationPct = todouble(WorkerCount) * 100.0 / MaximumInstances
| where SKUTier in ('Premium', 'PremiumV2', 'PremiumV3') and UtilizationPct < 30
| project name, SKUName, SKUTier, WorkerCount, MaximumInstances, UtilizationPct, subscriptionId
| order by UtilizationPct asc
```
