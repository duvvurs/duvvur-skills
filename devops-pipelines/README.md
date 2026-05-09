# DevOps Pipelines — FinOps Automation

> Azure DevOps / GitHub Actions pipelines for cost governance as code.

## Pipeline 1: Policy-as-Code Deployment

```yaml
# azure-pipelines.yml — Deploy FinOps policies on schedule
# Triggers: weekly (Monday 9am) + on policy file changes
trigger:
  paths:
    include:
      - bicep/policies/**
      - bicep/governance/**

schedules:
  - cron: "0 9 * * 1"
    displayName: "Weekly policy sync"
    branches:
      include: [main]

pool:
  vmImage: 'ubuntu-latest'

variables:
  azureSubscription: 'FinOps-Service-Connection'
  managementGroupId: '$(MANAGEMENT_GROUP_ID)'

stages:
  - stage: Validate
    jobs:
      - job: ValidatePolicies
        steps:
          - task: AzureCLI@2
            displayName: 'Validate Bicep templates'
            inputs:
              azureSubscription: $(azureSubscription)
              scriptType: bash
              scriptLocation: inlineScript
              inlineScript: |
                az deployment mg validate \
                  --management-group-id $(managementGroupId) \
                  --location westeurope \
                  --template-file bicep/policies/finops-policies.bicep

  - stage: Deploy
    dependsOn: Validate
    condition: succeeded()
    jobs:
      - job: DeployPolicies
        steps:
          - task: AzureCLI@2
            displayName: 'Deploy FinOps policies'
            inputs:
              azureSubscription: $(azureSubscription)
              scriptType: bash
              scriptLocation: inlineScript
              inlineScript: |
                az deployment mg create \
                  --management-group-id $(managementGroupId) \
                  --location westeurope \
                  --template-file bicep/policies/finops-policies.bicep

      - job: DeployGovernance
        dependsOn: DeployPolicies
        steps:
          - task: AzureCLI@2
            displayName: 'Deploy governance hierarchy + RBAC'
            inputs:
              azureSubscription: $(azureSubscription)
              scriptType: bash
              scriptLocation: inlineScript
              inlineScript: |
                az deployment mg create \
                  --management-group-id $(managementGroupId) \
                  --location westeurope \
                  --template-file bicep/governance/finops-governance.bicep
```

## Pipeline 2: Weekly Cost Report Generation

```yaml
# weekly-finops-report.yml — Generate and publish cost report
# Runs every Monday at 8am, produces CSV + summary for Power BI refresh
trigger: none

schedules:
  - cron: "0 8 * * 1"
    displayName: "Weekly FinOps report"
    branches:
      include: [main]

pool:
  vmImage: 'ubuntu-latest'

variables:
  azureSubscription: 'FinOps-Service-Connection'
  reportStorageAccount: '$(REPORT_STORAGE)'
  reportContainer: 'finops-reports'

steps:
  - task: AzurePowerShell@5
    displayName: 'Export cost data'
    inputs:
      azureSubscription: $(azureSubscription)
      ScriptType: 'FilePath'
      ScriptPath: 'powershell/cost-management/Export-AzCostData.ps1'
      ScriptArguments: >
        -SubscriptionIds $(SUBSCRIPTION_IDS)
        -DaysBack 30
        -OutputPath "$(Build.ArtifactStagingDirectory)/cost-export.csv"
      azurePowerShellVersion: 'LatestVersion'

  - task: AzurePowerShell@5
    displayName: 'Run tag compliance audit'
    inputs:
      azureSubscription: $(azureSubscription)
      ScriptType: 'FilePath'
      ScriptPath: 'powershell/governance/Invoke-TagComplianceAudit.ps1'
      ScriptArguments: >
        -SubscriptionIds $(SUBSCRIPTION_IDS)
        -Mode Report
      azurePowerShellVersion: 'LatestVersion'

  - task: AzurePowerShell@5
    displayName: 'Generate weekly summary'
    inputs:
      azureSubscription: $(azureSubscription)
      ScriptType: 'FilePath'
      ScriptPath: 'powershell/automation/Invoke-WeeklyFinOpsReport.ps1'
      ScriptArguments: >
        -SubscriptionIds $(SUBSCRIPTION_IDS)
        -ReportPath "$(Build.ArtifactStagingDirectory)"
      azurePowerShellVersion: 'LatestVersion'

  - task: AzureCLI@2
    displayName: 'Upload reports to storage (Power BI source)'
    inputs:
      azureSubscription: $(azureSubscription)
      scriptType: bash
      scriptLocation: inlineScript
      inlineScript: |
        az storage container create --name $(reportContainer) --account-name $(reportStorageAccount) --only-show-errors
        az storage blob upload-batch \
          --destination $(reportContainer) \
          --source "$(Build.ArtifactStagingDirectory)" \
          --account-name $(reportStorageAccount) \
          --overwrite
```

## GitHub Actions — FinOps Toolkit Sync

```yaml
# .github/workflows/finops-sync.yml
name: FinOps Weekly Sync

on:
  schedule:
    - cron: '0 7 * * 1'  # Monday 7am UTC
  workflow_dispatch:

jobs:
  cost-export:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Azure Login
        uses: azure/login@v2
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}

      - name: Run Cost Export
        uses: azure/powershell@v2
        with:
          inlineScript: |
            ./powershell/cost-management/Export-AzCostData.ps1 `
              -SubscriptionIds ${{ secrets.SUBSCRIPTION_IDS }}.Split(',') `
              -DaysBack 30 `
              -OutputPath "./reports/cost-export.csv"
          azPSVersion: "latest"

      - name: Upload Report
        uses: actions/upload-artifact@v4
        with:
          name: finops-report
          path: reports/
```
