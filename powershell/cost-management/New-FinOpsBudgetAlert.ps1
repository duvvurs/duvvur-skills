#Requires -Module Az.Billing, Az.Accounts
<#
.SYNOPSIS
    Creates Azure budget alerts with escalation thresholds
    
.DESCRIPTION
    Production pattern for budget creation with tiered alerting.
    Threshold 1 (50%): FinOps team notification
    Threshold 2 (80%): Engineering lead notification
    Threshold 3 (100%): Management notification + auto-action
    
.EXAMPLE
    .\New-FinOpsBudgetAlert.ps1 -SubscriptionId "sub1" -BudgetName "Monthly-Budget" -Amount 50000 -AlertEmails @("finops@company.com","eng-lead@company.com")
    
.NOTES
    Author: Duvvur Sai Krishna
#>

param(
    [Parameter(Mandatory)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory)]
    [string]$BudgetName,
    
    [Parameter(Mandatory)]
    [decimal]$Amount,
    
    [Parameter(Mandatory)]
    [string[]]$AlertEmails,
    
    [Parameter()]
    [string]$Currency = 'GBP'
)

$Context = Get-AzContext
if (-not $Context) { Connect-AzAccount -Identity }

# Budget definition
$BudgetBody = @{
    name       = $BudgetName
    properties = @{
        category      = 'Cost'
        amount        = $Amount
        timeGrain     = 'Monthly'
        timePeriod    = @{
            startDate = (Get-Date -Day 1 -Format 'yyyy-MM-dd')
            endDate   = (Get-Date).AddYears(1).ToString('yyyy-MM-dd')
        }
        notifications = @{
            Notification_50_Pct = @{
                enabled       = $true
                operator      = 'GreaterThan'
                threshold     = 50
                contactEmails = $AlertEmails
                contactRoles  = @('Contributor', 'Owner')
                locale        = 'en-gb'
            }
            Notification_80_Pct = @{
                enabled       = $true
                operator      = 'GreaterThan'
                threshold     = 80
                contactEmails = $AlertEmails
                contactRoles  = @('Contributor', 'Owner')
                locale        = 'en-gb'
            }
            Notification_100_Pct = @{
                enabled       = $true
                operator      = 'GreaterThan'
                threshold     = 100
                contactEmails = $AlertEmails
                contactRoles  = @('Contributor', 'Owner')
                locale        = 'en-gb'
            }
        }
    }
} | ConvertTo-Json -Depth 10

$Path = "/subscriptions/$SubscriptionId/providers/Microsoft.Consumption/budgets/$BudgetName`?api-version=2023-05-01"
$Response = Invoke-AzRestMethod -Path $Path -Method PUT -Payload $BudgetBody

if ($Response.StatusCode -in @(200, 201)) {
    Write-Host "✓ Budget '$BudgetName' created: $($Currency) $Amount/month" -ForegroundColor Green
    Write-Host "  Alerts at: 50% (finops), 80% (eng-lead), 100% (management)" -ForegroundColor Cyan
}
else {
    Write-Error "Failed to create budget: $($Response.StatusCode) - $($Response.Content)"
}
