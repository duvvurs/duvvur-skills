# Budget Escalation — PowerShell

> **Atomic skill:** Create Azure budgets with 4-tier alerting programmatically.
> **Cross-ref:** [`escalation-matrix/`](../../../cost-governance/budgeting-forecasting/escalation-matrix/) for the framework

## Script

```powershell
#Requires -Module Az.Billing, Az.Accounts

param(
    [Parameter(Mandatory)][string]$SubscriptionId,
    [Parameter(Mandatory)][string]$BudgetName,
    [Parameter(Mandatory)][decimal]$Amount,
    [Parameter(Mandatory)][string[]]$AlertEmails,
    [string]$Currency = 'GBP'
)

Set-AzContext -SubscriptionId $SubscriptionId | Out-Null

$Body = @{
  properties = @{
    category   = 'Cost'
    amount     = $Amount
    timeGrain  = 'Monthly'
    timePeriod = @{
      startDate = (Get-Date -Day 1 -Format 'yyyy-MM-dd')
      endDate   = (Get-Date).AddYears(1).ToString('yyyy-MM-dd')
    }
    notifications = @{
      Alert_50_Pct = @{
        enabled       = $true
        operator      = 'GreaterThan'
        threshold     = 50
        contactEmails = $AlertEmails
        contactRoles  = @('Contributor')
      }
      Alert_80_Pct = @{
        enabled       = $true
        operator      = 'GreaterThan'
        threshold     = 80
        contactEmails = $AlertEmails
        contactRoles  = @('Contributor', 'Owner')
      }
      Alert_100_Pct = @{
        enabled       = $true
        operator      = 'GreaterThan'
        threshold     = 100
        contactEmails = $AlertEmails
        contactRoles  = @('Contributor', 'Owner')
      }
      Alert_120_Pct = @{
        enabled       = $true
        operator      = 'GreaterThan'
        threshold     = 120
        contactEmails = $AlertEmails
        contactRoles  = @('Contributor', 'Owner')
      }
    }
  }
} | ConvertTo-Json -Depth 10

$Path = "/subscriptions/$SubscriptionId/providers/Microsoft.Consumption/budgets/$BudgetName`?api-version=2023-05-01"
$Response = Invoke-AzRestMethod -Path $Path -Method PUT -Payload $Body

if ($Response.StatusCode -in @(200, 201)) {
    Write-Host "✅ Budget '$BudgetName' created: $Currency $Amount/month" -ForegroundColor Green
    Write-Host "   Alerts: 50% (FinOps) → 80% (Eng Lead) → 100% (Dept Head) → 120% (VP/CFO)" -ForegroundColor Cyan
} else {
    Write-Error "Failed: $($Response.StatusCode)"
}
```

## Usage

```powershell
.\New-FinOpsBudgetWithEscalation.ps1 `
  -SubscriptionId "sub1" `
  -BudgetName "Monthly-FinOps" `
  -Amount 50000 `
  -AlertEmails @("finops@co.com","eng-lead@co.com","cfo@co.com")
```
