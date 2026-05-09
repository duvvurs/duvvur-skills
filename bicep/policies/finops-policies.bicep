// FinOps Policy Definitions — Bicep
// Enforce cost governance across management group / subscription
// Author: Duvvur Sai Krishna

// ═══════════════════════════════════════════════════════════
// Policy 1: Require cost-centre tag on all resources
// ═══════════════════════════════════════════════════════════

param policyName string = 'require-cost-centre-tag'
param policyDisplayName string = 'Require cost-centre tag on resources'
param policyDescription string = 'Enforces cost-centre tag for accurate showback/chargeback allocation. Resources without this tag cannot be cost-attributed.'
param managementGroupId string

resource requireCostCentreTag 'Microsoft.Authorization/policyDefinitions@2023-04-01' = {
  name: policyName
  properties: {
    displayName: policyDisplayName
    description: policyDescription
    policyType: 'Custom'
    mode: 'Indexed'
    metadata: {
      category: 'FinOps'
      version: '1.0.0'
    }
    parameters: {
      tagName: {
        type: 'String'
        metadata: {
          displayName: 'Tag Name'
          description: 'Name of the tag to require'
        }
        defaultValue: 'cost-centre'
      }
      tagValue: {
        type: 'String'
        metadata: {
          displayName: 'Tag Value Pattern'
          description: 'Regex pattern for valid cost-centre values'
        }
        defaultValue: '^[A-Z]{2,4}-[0-9]{3,6}$'
      }
    }
    policyRule: {
      if: {
        field: '[parameters(\'tagName\')]'
        exists: 'false'
      }
      then: {
        effect: 'deny'
      }
    }
  }
}

// ═══════════════════════════════════════════════════════════
// Policy 2: Require environment tag
// ═══════════════════════════════════════════════════════════

resource requireEnvironmentTag 'Microsoft.Authorization/policyDefinitions@2023-04-01' = {
  name: 'require-environment-tag'
  properties: {
    displayName: 'Require environment tag'
    description: 'All resources must be tagged with environment (dev/test/staging/prod) for cost segmentation.'
    policyType: 'Custom'
    mode: 'Indexed'
    metadata: {
      category: 'FinOps'
      version: '1.0.0'
    }
    parameters: {
      allowedValues: {
        type: 'Array'
        metadata: {
          displayName: 'Allowed environments'
        }
        defaultValue: [
          'dev'
          'test'
          'staging'
          'prod'
          'production'
          'non-prod'
          'uat'
        ]
      }
    }
    policyRule: {
      if: {
        allOf: [
          {
            field: 'tags[environment]'
            exists: 'false'
          }
        ]
      }
      then: {
        effect: 'audit'  // Start with audit, escalate to deny after 30 days
      }
    }
  }
}

// ═══════════════════════════════════════════════════════════
// Policy 3: Allowed VM SKUs — prevent expensive VMs
// ═══════════════════════════════════════════════════════════

resource allowedVMSkus 'Microsoft.Authorization/policyDefinitions@2023-04-01' = {
  name: 'finops-allowed-vm-skus'
  properties: {
    displayName: 'FinOps — Allowed VM SKUs'
    description: 'Restricts VM sizes to cost-effective options. Blocks premium/oversized SKUs unless explicitly exempted.'
    policyType: 'Custom'
    mode: 'Indexed'
    metadata: {
      category: 'FinOps'
      version: '1.0.0'
    }
    parameters: {
      listOfAllowedSKUs: {
        type: 'Array'
        metadata: {
          displayName: 'Allowed VM SKUs'
          description: 'List of cost-effective VM SKUs permitted in this scope'
        }
        defaultValue: [
          'Standard_B2s'
          'Standard_B2ms'
          'Standard_B4ms'
          'Standard_D2s_v5'
          'Standard_D4s_v5'
          'Standard_D8s_v5'
          'Standard_E2s_v5'
          'Standard_E4s_v5'
          'Standard_F2s_v2'
          'Standard_F4s_v2'
        ]
      }
    }
    policyRule: {
      if: {
        allOf: [
          {
            field: 'type'
            equals: 'Microsoft.Compute/virtualMachines'
          }
          {
            field: 'Microsoft.Compute/virtualMachines/sku.name'
            notIn: '[parameters(\'listOfAllowedSKUs\')]'
          }
        ]
      }
      then: {
        effect: 'deny'
      }
    }
  }
}

// ═══════════════════════════════════════════════════════════
// Policy 4: Deny expensive storage SKUs
// ═══════════════════════════════════════════════════════════

resource allowedStorageSKUs 'Microsoft.Authorization/policyDefinitions@2023-04-01' = {
  name: 'finops-allowed-storage-skus'
  properties: {
    displayName: 'FinOps — Allowed Storage Account SKUs'
    description: 'Prevents Premium_ZRS and Ultra SSD unless explicitly approved.'
    policyType: 'Custom'
    mode: 'Indexed'
    metadata: {
      category: 'FinOps'
      version: '1.0.0'
    }
    parameters: {
      deniedSKUs: {
        type: 'Array'
        defaultValue: [
          'Premium_ZRS'
          'UltraSSD_LRS'
        ]
      }
    }
    policyRule: {
      if: {
        allOf: [
          {
            field: 'type'
            equals: 'Microsoft.Storage/storageAccounts'
          }
          {
            field: 'Microsoft.Storage/storageAccounts/sku.name'
            in: '[parameters(\'deniedSKUs\')]'
          }
        ]
      }
      then: {
        effect: 'deny'
      }
    }
  }
}

output policyDefinitionIds array = [
  requireCostCentreTag.id
  requireEnvironmentTag.id
  allowedVMSkus.id
  allowedStorageSKUs.id
]
