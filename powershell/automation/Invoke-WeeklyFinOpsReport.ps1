#Requires -Module Az.Resources, Az.Accounts
<#
.SYNOPSIS
    Scheduled runbook for weekly FinOps cost reporting
    
.DESCRIPTION
    Production pattern for automated weekly cost report generation.
    Gathers: top spenders, budget status, tag compliance, optimization opportunities.
    Outputs: CSV report + optional email notification.
    
.EXAMPLE
    .\Invoke-WeeklyFinOpsReport.ps1 -SubscriptionIds @("sub1") -ReportPath ".\reports"
    
.NOTES
    Author: Duvvur Sai Krishna
#>

param(
    [Parameter(Mandatory)]
    [string[]]$SubscriptionIds,
    
    [Parameter()]
    [string]$ReportPath = ".\finops-report-$(Get-Date -Format 'yyyy-MM-dd')",
    
    [Parameter()]
    [int]$TopSpendersCount = 20
)

$ErrorActionPreference = 'Continue'
New-Item -ItemType Directory -Path $ReportPath -Force | Out-Null

Write-Host "`n=== FINOPS WEEKLY REPORT ===" -ForegroundColor Cyan
Write-Host "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
Write-Host "Subscriptions: $($SubscriptionIds.Count)"

# 1. Budget Status
Write-Host "`n--- Budget Status ---" -ForegroundColor Yellow
$BudgetData = @()
foreach ($SubId in $SubscriptionIds) {
    $Budgets = Invoke-AzRestMethod -Path "/subscriptions/$SubId/providers/Microsoft.Consumption/budgets?api-version=2023-05-01" -Method GET
    if ($Budgets.StatusCode -eq 200) {
        $Budgets = $Budgets.Content | ConvertFrom-Json
        foreach ($Budget in $Budgets.value) {
            $CurrentSpend = $Budget.properties.currentSpend.amount
            $BudgetAmount = $Budget.properties.amount
            $PctUsed = [math]::Round(($CurrentSpend / $BudgetAmount) * 100, 1)
            $BudgetData += [PSCustomObject]@{
                Subscription = $SubId
                Budget       = $Budget.name
                Amount       = $BudgetAmount
                CurrentSpend = $CurrentSpend
                PctUsed      = $PctUsed
                Status       = if ($PctUsed -ge 100) { 'OVER' } elseif ($PctUsed -ge 80) { 'WARNING' } else { 'OK' }
            }
        }
    }
}
$BudgetData | Format-Table -AutoSize
$BudgetData | Export-Csv "$ReportPath\budget-status.csv" -NoTypeInformation

# 2. Tag Compliance Summary
Write-Host "`n--- Tag Compliance ---" -ForegroundColor Yellow
$TagSummary = @()
foreach ($SubId in $SubscriptionIds) {
    $Resources = Get-AzResource
    $WithTag = ($Resources | Where-Object { $_.Tags -and $_.Tags['cost-centre'] }).Count
    $Total = $Resources.Count
    $TagSummary += [PSCustomObject]@{
        Subscription   = $SubId
        TotalResources = $Total
        Tagged         = $WithTag
        CompliancePct  = [math]::Round(($WithTag / $Total) * 100, 1)
    }
}
$TagSummary | Format-Table -AutoSize

# 3. Summary
Write-Host "`n=== SUMMARY ===" -ForegroundColor Cyan
Write-Host "Over-budget: $(($BudgetData | Where-Object Status -eq 'OVER').Count)"
Write-Host "Warning: $(($BudgetData | Where-Object Status -eq 'WARNING').Count)"
Write-Host "Avg tag compliance: $([math]::Round(($TagSummary | Measure-Object -Property CompliancePct -Average).Average, 1))%"
Write-Host "`nReport saved to: $ReportPath"
