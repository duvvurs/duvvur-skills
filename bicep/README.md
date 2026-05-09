# Bicep — Declarative Azure IaC

Modern Azure infrastructure-as-code for FinOps governance.

## Modules

| Module | File | Purpose |
|--------|------|---------|
| **Policies** | [`policies/finops-policies.bicep`](policies/finops-policies.bicep) | Tag enforcement, allowed SKUs, deny expensive storage |
| **Governance** | [`governance/finops-governance.bicep`](governance/finops-governance.bicep) | Management group hierarchy, custom RBAC roles |
