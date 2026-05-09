# Policy-as-Code Pipeline — DevOps

> **Atomic skill:** CI/CD pipeline that deploys FinOps policies automatically on every change.
> **Cross-ref:** [`tag-enforcement/`](../../bicep/policies/tag-enforcement/) and [`allowed-skus/`](../../bicep/policies/allowed-skus/) for the policies being deployed

## Azure Pipelines YAML

```yaml
trigger:
  paths:
    include:
      - bicep/policies/**
      - bicep/governance/**

pool:
  vmImage: 'ubuntu-latest'

variables:
  azureConnection: 'FinOps-Service-Connection'

stages:
  - stage: Validate
    jobs:
      - job: LintAndValidate
        steps:
          - task: AzureCLI@2
            displayName: 'Validate Bicep templates'
            inputs:
              azureSubscription: $(azureConnection)
              scriptType: bash
              scriptLocation: inlineScript
              inlineScript: |
                # Validate each policy file
                for f in bicep/policies/*.bicep; do
                  echo "Validating $f"
                  az deployment mg validate \
                    --management-group-id $(MG_ID) \
                    --location westeurope \
                    --template-file "$f" || exit 1
                done

  - stage: Deploy
    dependsOn: Validate
    condition: succeeded()
    jobs:
      - job: DeployPolicies
        steps:
          - task: AzureCLI@2
            displayName: 'Deploy FinOps policies'
            inputs:
              azureSubscription: $(azureConnection)
              scriptType: bash
              scriptLocation: inlineScript
              inlineScript: |
                az deployment mg create \
                  --management-group-id $(MG_ID) \
                  --location westeurope \
                  --template-file bicep/policies/finops-policies.bicep

      - job: DeployGovernance
        dependsOn: DeployPolicies
        steps:
          - task: AzureCLI@2
            displayName: 'Deploy RBAC roles'
            inputs:
              azureSubscription: $(azureConnection)
              scriptType: bash
              scriptLocation: inlineScript
                az deployment mg create \
                  --management-group-id $(MG_ID) \
                  --location westeurope \
                  --template-file bicep/governance/custom-roles.bicep

  - stage: ComplianceCheck
    dependsOn: Deploy
    condition: always()
    jobs:
      - job: CheckCompliance
        steps:
          - task: AzurePowerShell@5
            displayName: 'Run tag compliance audit'
            inputs:
              azureSubscription: $(azureConnection)
              ScriptType: 'FilePath'
              ScriptPath: 'powershell/governance/tag-enforcement.ps1'
              ScriptArguments: '-SubscriptionIds $(SUB_IDS) -Mode Audit'
              azurePowerShellVersion: 'LatestVersion'
```

## GitHub Actions Version

```yaml
name: FinOps Policy Deploy
on:
  push:
    paths: ['bicep/**']
  workflow_dispatch:

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: azure/login@v2
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}
      - name: Deploy policies
        run: |
          az deployment mg create \
            --management-group-id ${{ secrets.MG_ID }} \
            --location westeurope \
            --template-file bicep/policies/finops-policies.bicep
```
