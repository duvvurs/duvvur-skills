#Requires -Module Az.CostManagement, Az.Accounts
<#
.SYNOPSIS
    Exports Azure cost data for all accessible subscriptions
    
.DESCRIPTION
    Production pattern for exporting cost data from Azure Cost Management API.
    Exports to CSV for Power BI consumption. Run as scheduled Azure Automation runbook.
    
.EXAMPLE
    .\Export-AzCostData.ps1 -SubscriptionIds @("sub1","sub2") -DaysBack 30 -OutputPath ".\cost-export.csv"
    
.NOTES
    Author: Duvvur Sai Krishna
    Pattern derived from European insurance FinOps practice
#>

param(
    [Parameter(Mandatory)]
    [string[]]$SubscriptionIds,
    
    [Parameter()]
    [int]$DaysBack = 30,
    
    [Parameter()]
    [string]$OutputPath = ".\cost-export-$(Get-Date -Format 'yyyy-MM-dd').csv",
    
    [Parameter()]
    [ValidateSet('Daily', 'Monthly')]
    [string]$Granularity = 'Daily'
)

# Connect if not already connected
if (-not (Get-AzContext)) {
    Connect-AzAccount -Identity
}

$EndDate = Get-Date
$StartDate = $EndDate.AddDays(-$DaysBack)
$AllCostData = @()

foreach ($SubId in $SubscriptionIds) {
    Write-Host "Processing subscription: $SubId" -ForegroundColor Cyan
    
    try {
        # Query Cost Management API
        $Query = @{
            Type        = 'ActualCost'
            Timeframe   = 'Custom'
            TimePeriod  = @{
                From = $StartDate.ToString('yyyy-MM-dd')
                To   = $EndDate.ToString('yyyy-MM-dd')
            }
            Dataset = @{
                Granularity = $Granularity
                Aggregation = @{
                    totalCost = @{
                        Name     = 'Cost'
                        Function = 'Sum'
                    }
                }
                Grouping = @(
                    @{ Name = 'ResourceGroup'; Type = 'Dimension' },
                    @{ Name = 'ResourceType'; Type = 'Dimension' },
                    @{ Name = 'MeterCategory'; Type = 'Dimension' },
                    @{ Name = 'MeterSubCategory'; Type = 'Dimension' }
                )
            }
        } | ConvertTo-Json -Depth 10
        
        $Response = Invoke-AzRestMethod `
            -Path "/subscriptions/$SubId/providers/Microsoft.CostManagement/query?api-version=2023-11-01" `
            -Method POST `
            -Payload $Query
        
        if ($Response.StatusCode -eq 200) {
            $CostData = $Response.Content | ConvertFrom-Json
            foreach ($Row in $CostData.properties.rows) {
                $AllCostData += [PSCustomObject]@{
                    Date             = $Row[1]
                    SubscriptionId   = $SubId
                    ResourceGroup    = $Row[2]
                    ResourceType     = $Row[3]
                    MeterCategory    = $Row[4]
                    MeterSubCategory = $Row[5]
                    Cost             = [math]::Round($Row[0], 2)
                    Currency         = $CostData.properties.columns[-1].name
                }
            }
            Write-Host "  ✓ Exported $($CostData.properties.rows.Count) rows" -ForegroundColor Green
        }
        else {
            Write-Warning "  ✗ Failed for $SubId : $($Response.StatusCode)"
        }
    }
    catch {
        Write-Error "Error processing $SubId : $_"
    }
}

# Export to CSV
$AllCostData | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
Write-Host "`nExported $($AllCostData.Count) rows to $OutputPath" -ForegroundColor Green
