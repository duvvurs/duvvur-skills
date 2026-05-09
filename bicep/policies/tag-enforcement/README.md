# Tag Enforcement Policy — Bicep

> **Atomic skill:** Azure Policy that denies resource creation without required tags.
> **Source:** [`azure-policy fork/samples/FinOps/`](https://github.com/duvvurs/azure-policy/blob/master/samples/FinOps/)
> **Cross-ref:** [`tag-audit/`](../../../kql/governance-compliance/tag-audit/) for compliance measurement

## Bicep Definition

```bicep
@description('Tag name to enforce')
param tagName string = 'cost-centre'

@description('Start with audit, escalate to deny after compliance > 85%')
param effect string = 'audit'

resource enforceTag 'Microsoft.Authorization/policyDefinitions@2023-04-01' = {
  name: 'finops-require-${tagName}'
  properties: {
    displayName: 'FinOps — Require ${tagName} tag'
    description: 'Resources must have the ${tagName} tag for cost allocation. Part of the FinOps tagging taxonomy.'
    policyType: 'Custom'
    mode: 'Indexed'
    metadata: {
      category: 'FinOps'
      version: '1.0.0'
    }
    parameters: {
      effect: {
        type: 'String'
        allowedValues: [
          'Audit'
          'Deny'
        ]
        defaultValue: 'Audit'
        metadata: {
          displayName: 'Policy Effect'
          description: 'Audit first, escalate to Deny after compliance > 85%'
        }
      }
    }
    policyRule: {
      if: {
        anyOf: [
          {
            field: 'tags[${tagName}]'
            exists: 'false'
          }
          {
            field: 'tags[${tagName}]'
            equals: ''
          }
        ]
      }
      then: {
        effect: '[parameters(\'effect\')]'
      }
    }
  }
}

// Assignment at management group scope
resource assignTag 'Microsoft.Authorization/policyAssignments@2023-04-01' = {
  name: 'finops-assign-${tagName}'
  properties: {
    policyDefinitionId: enforceTag.id
    enforcementMode: 'Default'
    parameters: {
      effect: { value: effect }
    }
  }
}
```

## Rollout Phases

```bash
# Phase 1: Audit (weeks 1-4)
az deployment mg create --template-file tag-enforcement.bicep \
  --parameters tagName=cost-centre effect=Audit

# Phase 3: Deny (week 13+)
az deployment mg create --template-file tag-enforcement.bicep \
  --parameters tagName=cost-centre effect=Deny
```
