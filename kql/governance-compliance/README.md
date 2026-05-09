// Tag Compliance Audit
// Purpose: Measure tagging compliance across all subscriptions
// Business question: "What % of resources have all required tags?"
// Target: >90% compliance for effective showback/chargeback

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
| extend CompliancePct = todouble(PresentTags) * 100.0 / RequiredTags
| summarize 
    TotalResources = count(),
    AvgCompliance = avg(CompliancePct),
    FullyCompliant = countif(CompliancePct == 100),
    MissingCostCentre = countif(not(HasCostCentre)),
    MissingEnvironment = countif(not(HasEnvironment)),
    MissingWorkload = countif(not(HasWorkload)),
    MissingOwner = countif(not(HasOwner)),
    MissingDepartment = countif(not(HasDepartment)),
    MissingDataClassification = countif(not(HasDataClassification))
    by subscriptionId
| extend FullCompliancePct = todouble(FullyCompliant) * 100.0 / TotalResources
| order by AvgCompliance asc
```

### Policy Compliance — FinOps Policies

```kql
// Check compliance with cost-related Azure Policies
// Business question: "Are our cost governance policies actually being enforced?"
// Use case: Monthly governance review

PolicyResources
| where type =~ 'microsoft.policyinsights/policystates'
| where properties.policyDefinitionName contains 'allowed-skus' 
    or properties.policyDefinitionName contains 'require-tag'
    or properties.policyDefinitionName contains 'audit-cost'
| extend 
    PolicyName = tostring(properties.policyDefinitionName),
    ComplianceState = tostring(properties.complianceState),
    ResourceGroup = tostring(properties.resourceGroup),
    SubscriptionId = tostring(properties.subscriptionId)
| summarize 
    Total = count(),
    Compliant = countif(ComplianceState == 'Compliant'),
    NonCompliant = countif(ComplianceState == 'NonCompliant')
    by PolicyName
| extend CompliancePct = todouble(Compliant) * 100.0 / Total
| order by CompliancePct asc
```

### RBAC Assignment Drift

```kql
// Detect RBAC assignments that don't match governance baseline
// Business question: "Who has Owner/Contributor that shouldn't?"
// Use case: Quarterly access review, least-privilege enforcement

AuthorizationResources
| where type =~ 'microsoft.authorization/roleassignments'
| extend 
    RoleDefinitionId = tostring(properties.roleDefinitionId),
    PrincipalId = tostring(properties.principalId),
    Scope = tostring(properties.scope)
| where RoleDefinitionId contains 'owner' or RoleDefinitionId contains 'contributor'
| extend IsManagementGroup = Scope contains '/managementgroups/'
| extend IsSubscription = Scope contains '/subscriptions/' and not(Scope contains '/resourcegroups/')
| extend IsResourceGroup = Scope contains '/resourcegroups/'
| summarize 
    HighPrivilegeAssignments = count(),
    AtMgmtGroup = countif(IsManagementGroup),
    AtSubscription = countif(IsSubscription),
    AtResourceGroup = countif(IsResourceGroup)
    by PrincipalId
| where HighPrivilegeAssignments > 3
| order by HighPrivilegeAssignments desc
```

### Management Group Hierarchy Audit

```kql
// Validate management group structure matches governance design
// Business question: "Are all subscriptions in the right management group?"
// Use case: Governance onboarding verification

ResourceContainers
| where type =~ 'microsoft.management/managementgroups'
| extend 
    DisplayName = tostring(properties.displayName),
    ParentId = tostring(properties.parent.id)
| project 
    ManagementGroupId = id,
    DisplayName,
    ParentId,
    Type = type
| order by DisplayName
```

### Resource Age Analysis — Stale Resources

```kql
// Find resources that may be candidates for decommissioning
// Business question: "What hasn't been touched in 90+ days?"
// Use case: Cost optimization — identify zombie resources

Resources
| extend 
    CreatedTime = tostring(properties.creationTime),
    ChangedTime = tostring(properties.changedTime)
| where isnotempty(CreatedTime)
| extend AgeDays = datetime_diff('day', now(), todatetime(CreatedTime))
| where AgeDays > 90
| where type in (
    'microsoft.compute/virtualmachines',
    'microsoft.sql/servers',
    'microsoft.web/sites',
    'microsoft.storage/storageaccounts'
)
| summarize 
    StaleCount = count(),
    AvgAge = avg(todouble(AgeDays)),
    MaxAge = max(todouble(AgeDays))
    by type, subscriptionId
| order by StaleCount desc
```

### Subscription Quota Utilisation

```kql
// Check resource counts vs subscription limits
// Business question: "Are we approaching any subscription quotas?"
// Use case: Proactive capacity planning, subscription rationalisation

Resources
| summarize Count = count() by type, subscriptionId
| where type in (
    'microsoft.compute/virtualmachines',
    'microsoft.storage/storageaccounts',
    'microsoft.network/virtualnetworks',
    'microsoft.network/publicipaddresses'
)
| extend QuotaWarning = iff(
    type =~ 'microsoft.compute/virtualmachines' and Count > 20000, 'Near Limit',
    iff(type =~ 'microsoft.storage/storageaccounts' and Count > 240, 'Near Limit',
    iff(type =~ 'microsoft.network/virtualnetworks' and Count > 900, 'Near Limit',
    'OK'))
)
| order by Count desc
```
