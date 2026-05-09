// FinOps Governance — Management Group Structure + Custom RBAC
// Production pattern for enterprise Azure governance hierarchy
// Author: Duvvur Sai Krishna

// ═══════════════════════════════════════════════════════════
// Management Group Hierarchy
// ═══════════════════════════════════════════════════════════

param topLevelGroupName string = 'Enterprise'
param companyName string = 'Contoso'

// Top-level management group
resource topLevel 'Microsoft.Management/managementGroups@2023-04-01' = {
  name: topLevelGroupName
  properties: {
    displayName: '${companyName} — Enterprise'
  }
}

// Tier 2: Environment separation
resource mgProd 'Microsoft.Management/managementGroups@2023-04-01' = {
  name: '${companyName}-Production'
  properties: {
    displayName: 'Production'
    parentId: topLevel.id
  }
}

resource mgNonProd 'Microsoft.Management/managementGroups@2023-04-01' = {
  name: '${companyName}-NonProduction'
  properties: {
    displayName: 'Non-Production'
    parentId: topLevel.id
  }
}

resource mgSandbox 'Microsoft.Management/managementGroups@2023-04-01' = {
  name: '${companyName}-Sandbox'
  properties: {
    displayName: 'Sandbox (Auto-Cleanup)'
    parentId: topLevel.id
  }
}

// ═══════════════════════════════════════════════════════════
// Custom RBAC Roles for FinOps
// ═══════════════════════════════════════════════════════════

// FinOps Reader — Can view cost data but not modify resources
resource finOpsReader 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: guid('finops-reader-role')
  properties: {
    roleName: 'FinOps Reader'
    description: 'Can view cost data, budgets, and recommendations across subscriptions. Cannot modify resources.'
    type: 'CustomRole'
    permissions: [
      {
        actions: [
          'Microsoft.Consumption/*/read'
          'Microsoft.CostManagement/*/read'
          'Microsoft.Billing/*/read'
          'Microsoft.Resources/subscriptions/read'
          'Microsoft.ResourceHealth/*/read'
          'Microsoft.ResourceGraph/*/read'
          'Microsoft.PolicyInsights/*/read'
        ]
        notActions: [
          'Microsoft.Authorization/*/write'
          'Microsoft.Resources/*/write'
        ]
        dataActions: []
        notDataActions: []
      }
    ]
    assignableScopes: [
      topLevel.id
    ]
  }
}

// Cost Optimization Contributor — Can apply recommendations
resource costOptContrib 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: guid('cost-optimization-contributor-role')
  properties: {
    roleName: 'Cost Optimization Contributor'
    description: 'Can view cost data AND apply optimization actions (rightsizing, schedule shutdowns). Cannot delete resources or change policies.'
    type: 'CustomRole'
    permissions: [
      {
        actions: [
          'Microsoft.Consumption/*/read'
          'Microsoft.CostManagement/*/read'
          'Microsoft.CostManagement/*/action'
          'Microsoft.Resources/subscriptions/read'
          'Microsoft.ResourceGraph/*/read'
          'Microsoft.Compute/virtualMachines/start/action'
          'Microsoft.Compute/virtualMachines/deallocate/action'
          'Microsoft.Compute/virtualMachines/restart/action'
          'Microsoft.Sql/servers/databases/pause/action'
          'Microsoft.Sql/servers/databases/resume/action'
        ]
        notActions: [
          'Microsoft.Compute/virtualMachines/delete'
          'Microsoft.Authorization/*/write'
          'Microsoft.Resources/subscriptions/delete'
        ]
        dataActions: []
        notDataActions: []
      }
    ]
    assignableScopes: [
      topLevel.id
    ]
  }
}

// Budget Owner — Manages budgets and alerts for their scope
resource budgetOwner 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: guid('budget-owner-role')
  properties: {
    roleName: 'Budget Owner'
    description: 'Can create and manage budgets and alerts within their assigned scope. Full cost visibility.'
    type: 'CustomRole'
    permissions: [
      {
        actions: [
          'Microsoft.Consumption/*/read'
          'Microsoft.Consumption/budgets/*/read'
          'Microsoft.Consumption/budgets/write'
          'Microsoft.Consumption/budgets/delete'
          'Microsoft.CostManagement/*/read'
          'Microsoft.Resources/subscriptions/read'
          'Microsoft.ResourceGraph/*/read'
          'Microsoft.Insights/actionGroups/*'
        ]
        notActions: []
        dataActions: []
        notDataActions: []
      }
    ]
    assignableScopes: [
      topLevel.id
    ]
  }
}

output managementGroupIds object = {
  production: mgProd.id
  nonProduction: mgNonProd.id
  sandbox: mgSandbox.id
}

output customRoleIds object = {
  finOpsReader: finOpsReader.id
  costOptimizationContributor: costOptContrib.id
  budgetOwner: budgetOwner.id
}
