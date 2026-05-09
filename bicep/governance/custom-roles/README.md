# Custom RBAC Roles — Bicep

> **Atomic skill:** Deploy 3 FinOps-specific custom roles via Bicep.
> **Cross-ref:** [`least-privilege/`](../../../cost-governance/rbac-models/least-privilege/) for the role definitions

## Bicep Definition

```bicep
param managementGroupId string
param companyName string = 'Contoso'

// Top-level management group
resource mg 'Microsoft.Management/managementGroups@2023-04-01' = {
  name: '${companyName}-FinOps'
  properties: {
    displayName: '${companyName} — FinOps Governance'
  }
}

// FinOps Reader — cost visibility only
resource finopsReader 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: guid('finops-reader-${companyName}')
  properties: {
    roleName: 'FinOps Reader'
    description: 'View cost data, budgets, recommendations. No infrastructure modification.'
    type: 'CustomRole'
    permissions: [{
      actions: [
        'Microsoft.Consumption/*/read'
        'Microsoft.CostManagement/*/read'
        'Microsoft.Billing/*/read'
        'Microsoft.Resources/subscriptions/read'
        'Microsoft.ResourceGraph/*/read'
        'Microsoft.PolicyInsights/*/read'
      ]
      notActions: [
        'Microsoft.Authorization/*/write'
        'Microsoft.Resources/*/write'
        'Microsoft.Compute/*/write'
      ]
    }]
    assignableScopes: [ mg.id ]
  }
}

// Cost Optimization Contributor — apply savings actions
resource costOptimizer 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: guid('cost-optimizer-${companyName}')
  properties: {
    roleName: 'Cost Optimization Contributor'
    description: 'Start/stop VMs, pause SQL, manage budgets. Cannot delete or change policies.'
    type: 'CustomRole'
    permissions: [{
      actions: [
        'Microsoft.Consumption/*/read'
        'Microsoft.CostManagement/*/read'
        'Microsoft.Compute/virtualMachines/start/action'
        'Microsoft.Compute/virtualMachines/deallocate/action'
        'Microsoft.Sql/servers/databases/pause/action'
        'Microsoft.Sql/servers/databases/resume/action'
        'Microsoft.Consumption/budgets/*'
      ]
      notActions: [
        'Microsoft.Compute/virtualMachines/delete'
        'Microsoft.Authorization/*/write'
      ]
    }]
    assignableScopes: [ mg.id ]
  }
}

// Budget Owner — manage budgets for their scope
resource budgetOwner 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: guid('budget-owner-${companyName}')
  properties: {
    roleName: 'Budget Owner'
    description: 'Create and manage budgets within assigned scope. Full cost visibility.'
    type: 'CustomRole'
    permissions: [{
      actions: [
        'Microsoft.Consumption/*/read'
        'Microsoft.Consumption/budgets/*'
        'Microsoft.CostManagement/*/read'
        'Microsoft.Insights/actionGroups/*'
      ]
      notActions: []
    }]
    assignableScopes: [ mg.id ]
  }
}

output roleIds object = {
  finopsReader: finopsReader.id
  costOptimizer: costOptimizer.id
  budgetOwner: budgetOwner.id
}
```

## Deploy

```bash
az deployment mg create \
  --management-group-id {mgId} \
  --location westeurope \
  --template-file custom-roles.bicep \
  --parameters companyName=MyCompany
```
