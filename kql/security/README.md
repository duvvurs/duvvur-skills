// Expensive resources without encryption at rest
// Business question: "Are we paying for resources that don't meet security baselines?"
// Use case: Security-informed cost optimization

Resources
| where type in (
    'microsoft.compute/virtualmachines',
    'microsoft.sql/servers',
    'microsoft.storage/storageaccounts'
)
| extend EncryptionEnabled = 
    iff(type =~ 'microsoft.storage/storageaccounts', tostring(properties.encryption.services.blob.enabled), 'unknown')
| where EncryptionEnabled == 'false' or EncryptionEnabled == 'unknown'
| summarize UnencryptedCount = count() by type, subscriptionId
| order by UnencryptedCount desc
```

### NSG Rules Allowing Unrestricted Inbound

```kql
// Find expensive resources with overly permissive network rules
// Business question: "Which resources have public exposure AND high cost?"
// Use case: Prioritize security remediation by cost impact

Resources
| where type =~ 'microsoft.network/networksecuritygroups'
| mv-expand rules = properties.securityRules
| extend 
    Direction = tostring(rules.properties.direction),
    Access = tostring(rules.properties.access),
    SourcePrefix = tostring(rules.properties.sourceAddressPrefix),
    DestinationPort = tostring(rules.properties.destinationPortRange)
| where Direction =~ 'Inbound' and Access =~ 'Allow' and SourcePrefix in ('*', '0.0.0.0', '0.0.0.0/0', 'Internet')
| project name, RuleName = tostring(rules.name), DestinationPort, subscriptionId
```

### Resources Without Backup

```kql
// Find production VMs without backup configured
// Business question: "Which expensive VMs have no disaster recovery?"
// Use case: Risk-weighted cost review — backup cost vs data loss cost

Resources
| where type =~ 'microsoft.compute/virtualmachines'
| extend Tags = tags
| where tostring(tags['environment']) =~ 'production' or tostring(tags['Environment']) =~ 'production'
| project VMName = name, SubscriptionId = subscriptionId, ResourceGroup = resourceGroup, Tags
| join kind=leftanti (
    Resources
    | where type =~ 'microsoft.recoveryservices/vaults/backupfabrics/protectioncontainers/protecteditems'
    | extend SourceId = tostring(properties.sourceResourceId)
    | project SourceId
) on $left.VMName == $right.SourceId
```
