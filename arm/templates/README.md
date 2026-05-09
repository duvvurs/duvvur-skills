# ARM Template Patterns — Classic Azure IaC

> Legacy ARM templates still used across many Azure environments. These patterns bridge the gap while migrating to Bicep.

## FinOps Budget ARM Template

```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "budgetName": {
      "type": "string",
      "defaultValue": "monthly-finops-budget",
      "metadata": { "description": "Name of the budget" }
    },
    "budgetAmount": {
      "type": "double",
      "metadata": { "description": "Monthly budget amount in GBP" }
    },
    "alertEmails": {
      "type": "array",
      "metadata": { "description": "Email addresses for budget alerts" }
    },
    "timeGrain": {
      "type": "string",
      "defaultValue": "Monthly",
      "allowedValues": ["Monthly", "Quarterly", "Annually"]
    }
  },
  "resources": [
    {
      "type": "Microsoft.Consumption/budgets",
      "apiVersion": "2023-05-01",
      "name": "[parameters('budgetName')]",
      "properties": {
        "category": "Cost",
        "amount": "[parameters('budgetAmount')]",
        "timeGrain": "[parameters('timeGrain')]",
        "timePeriod": {
          "startDate": "[utcNow('yyyy-MM-dd')]",
          "endDate": "[dateTimeAdd(utcNow('yyyy-MM-dd'), 'P1Y')]"
        },
        "notifications": {
          "Alert_50": {
            "enabled": true,
            "operator": "GreaterThan",
            "threshold": 50,
            "contactEmails": "[parameters('alertEmails')]",
            "contactRoles": ["Contributor"]
          },
          "Alert_80": {
            "enabled": true,
            "operator": "GreaterThan",
            "threshold": 80,
            "contactEmails": "[parameters('alertEmails')]",
            "contactRoles": ["Contributor", "Owner"]
          },
          "Alert_100": {
            "enabled": true,
            "operator": "GreaterThan",
            "threshold": 100,
            "contactEmails": "[parameters('alertEmails')]",
            "contactRoles": ["Contributor", "Owner"]
          }
        }
      }
    }
  ]
}
```

## Cost Management Export ARM Template

```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "exportName": {
      "type": "string",
      "defaultValue": "daily-cost-export"
    },
    "storageAccountId": {
      "type": "string",
      "metadata": { "description": "Resource ID of storage account for cost data" }
    },
    "containerName": {
      "type": "string",
      "defaultValue": "cost-exports"
    }
  },
  "resources": [
    {
      "type": "Microsoft.CostManagement/exports",
      "apiVersion": "2023-11-01",
      "name": "[parameters('exportName')]",
      "properties": {
        "format": "Csv",
        "deliveryInfo": {
          "destination": {
            "resourceId": "[parameters('storageAccountId')]",
            "container": "[parameters('containerName')]",
            "rootFolderPath": "daily"
          }
        },
        "definition": {
          "type": "ActualCost",
          "timeframe": "MonthToDate",
          "dataSet": {
            "granularity": "Daily",
            "configuration": {
              "columns": [
                "Date", "SubscriptionId", "ResourceGroup", "ResourceType",
                "ResourceName", "MeterCategory", "MeterSubCategory",
                "Cost", "Currency", "TagCostCentre", "TagEnvironment"
              ]
            }
          }
        },
        "schedule": {
          "status": "Active",
          "recurrence": "Daily",
          "recurrencePeriod": {
            "from": "[utcNow('yyyy-MM-dd')]",
            "to": "[dateTimeAdd(utcNow('yyyy-MM-dd'), 'P1Y')]"
          }
        }
      }
    }
  ]
}
```

## Policy Assignment ARM Template

```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "policyDefinitionId": {
      "type": "string",
      "metadata": { "description": "Full resource ID of the policy definition" }
    },
    "assignmentName": {
      "type": "string",
      "defaultValue": "finops-require-cost-centre"
    }
  },
  "resources": [
    {
      "type": "Microsoft.Authorization/policyAssignments",
      "apiVersion": "2023-04-01",
      "name": "[parameters('assignmentName')]",
      "properties": {
        "displayName": "FinOps — Require cost-centre tag",
        "policyDefinitionId": "[parameters('policyDefinitionId')]",
        "enforcementMode": "Default",
        "parameters": {},
        "nonComplianceMessages": [
          {
            "message": "Resources must have a cost-centre tag for showback/chargeback allocation. Contact the FinOps team."
          }
        ]
      }
    }
  ]
}
```
