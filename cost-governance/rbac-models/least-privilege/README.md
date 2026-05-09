# Least-Privilege RBAC — Custom Role Definitions

> **Atomic skill:** 3 custom Azure roles for FinOps teams — view cost without modifying infra.
> **Cross-ref:** [`rbac-drift/`](../../../kql/governance-compliance/rbac-drift/) for detecting violations, [`custom-roles/`](../../../bicep/governance/custom-roles/) for Bicep deployment

## Role 1: FinOps Reader

**Who:** Finance, leadership, executives who need cost visibility without any infra access.

```json
{
  "properties": {
    "roleName": "FinOps Reader",
    "description": "View cost data, budgets, and recommendations. Cannot modify resources.",
    "type": "CustomRole",
    "permissions": [{
      "actions": [
        "Microsoft.Consumption/*/read",
        "Microsoft.CostManagement/*/read",
        "Microsoft.Billing/*/read",
        "Microsoft.Resources/subscriptions/read",
        "Microsoft.ResourceGraph/*/read",
        "Microsoft.PolicyInsights/*/read",
        "Microsoft.Advisor/*/read"
      ],
      "notActions": [
        "Microsoft.Authorization/*/write",
        "Microsoft.Resources/*/write"
      ]
    }],
    "assignableScopes": ["/providers/Microsoft.Management/managementGroups/{mgId}"]
  }
}
```

## Role 2: Cost Optimization Contributor

**Who:** FinOps engineers who apply rightsizing and schedule shutdowns.

```json
{
  "properties": {
    "roleName": "Cost Optimization Contributor",
    "description": "Apply cost optimization: start/stop VMs, pause SQL, manage budgets. Cannot delete resources or change policies.",
    "type": "CustomRole",
    "permissions": [{
      "actions": [
        "Microsoft.Consumption/*/read",
        "Microsoft.CostManagement/*/read",
        "Microsoft.CostManagement/*/action",
        "Microsoft.Compute/virtualMachines/read",
        "Microsoft.Compute/virtualMachines/start/action",
        "Microsoft.Compute/virtualMachines/deallocate/action",
        "Microsoft.Sql/servers/databases/pause/action",
        "Microsoft.Sql/servers/databases/resume/action",
        "Microsoft.Consumption/budgets/*"
      ],
      "notActions": [
        "Microsoft.Compute/virtualMachines/delete",
        "Microsoft.Authorization/*/write",
        "Microsoft.PolicyInsights/*/write"
      ]
    }]
  }
}
```

## Role 3: Budget Owner

**Who:** Engineering leads who manage budgets for their team's scope.

```json
{
  "properties": {
    "roleName": "Budget Owner",
    "description": "Create and manage budgets within assigned scope. No resource modification.",
    "type": "CustomRole",
    "permissions": [{
      "actions": [
        "Microsoft.Consumption/*/read",
        "Microsoft.Consumption/budgets/write",
        "Microsoft.Consumption/budgets/delete",
        "Microsoft.CostManagement/*/read",
        "Microsoft.Resources/subscriptions/read",
        "Microsoft.Insights/actionGroups/*"
      ],
      "notActions": ["Microsoft.Resources/*/write", "Microsoft.Compute/*/write"]
    }]
  }
}
```

## Assignment Matrix

| Role | MG Scope | Sub Scope | RG Scope | Who |
|------|:---:|:---:|:---:|-----|
| Owner | Platform only | ❌ | ❌ | Azure platform team |
| Cost Optimization Contributor | ❌ | ✅ | ✅ | FinOps engineers |
| FinOps Reader | ✅ All | ✅ All | ✅ All | Finance, leadership |
| Budget Owner | ❌ | ✅ Owned | ✅ Owned | Engineering leads |
| Reader | ❌ | ✅ All | ✅ All | All engineers (default) |
