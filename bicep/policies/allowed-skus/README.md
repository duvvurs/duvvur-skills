# Allowed VM SKUs Policy — Bicep

> **Atomic skill:** Restrict VM sizes to cost-effective options, blocking over-provisioning at deploy time.
> **Source:** [`azure-policy fork/samples/FinOps/allowed-vm-skus-finops.json`](https://github.com/duvvurs/azure-policy/blob/master/samples/FinOps/allowed-vm-skus-finops.json)

## Bicep Definition

```bicep
@description('Cost-effective VM SKUs allowed in this scope')
param allowedSKUs array = [
  'Standard_B2s'
  'Standard_B2ms'
  'Standard_B4ms'
  'Standard_D2s_v5'
  'Standard_D4s_v5'
  'Standard_D8s_v5'
  'Standard_D16s_v5'
  'Standard_E2s_v5'
  'Standard_E4s_v5'
  'Standard_E8s_v5'
  'Standard_F2s_v2'
  'Standard_F4s_v2'
  'Standard_F8s_v2'
]

resource allowedVMs 'Microsoft.Authorization/policyDefinitions@2023-04-01' = {
  name: 'finops-allowed-vm-skus'
  properties: {
    displayName: 'FinOps — Allowed VM SKUs'
    description: 'Restricts VM sizes to cost-effective options. Add exemptions for workloads that genuinely require premium sizes.'
    policyType: 'Custom'
    mode: 'Indexed'
    metadata: {
      category: 'FinOps'
      version: '1.0.0'
    }
    parameters: {
      listOfAllowedSKUs: {
        type: 'Array'
        defaultValue: allowedSKUs
        metadata: {
          displayName: 'Allowed VM SKUs'
          description: 'VM sizes permitted for deployment'
        }
      }
    }
    policyRule: {
      if: {
        allOf: [
          { field: 'type', equals: 'Microsoft.Compute/virtualMachines' }
          { field: 'Microsoft.Compute/virtualMachines/sku.name', notIn: '[parameters(\'listOfAllowedSKUs\')]' }
        ]
      }
      then: { effect: 'Deny' }
    }
  }
}
```

## SKU Tier Strategy

| Tier | SKUs | Use Case |
|------|------|----------|
| **Burstable** | B2s, B2ms, B4ms | Dev/test, low-traffic web |
| **General** | D2s–D16s v5 | Production compute, APIs |
| **Memory** | E2s–E8s v5 | Databases, in-memory processing |
| **Compute** | F2s–F8s v2 | Batch processing, analytics |
| **Blocked** | D32s+, E16s+, F16s+, G-series, M-series | Require exemption approval |
