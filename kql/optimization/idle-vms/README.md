# Idle VMs — KQL + PowerShell

> **Atomic skill:** Find running VMs with near-zero CPU — the highest-impact cost optimization action.
> **Business question:** "Which VMs can we stop or delete today?"
> **Savings potential:** 20-40% of total compute spend
> **Cross-ref:** [`rightsizing-assessment/`](../../../powershell/automation/rightsizing-assessment/) for automated SKU recommendations

## KQL — Identify Candidates

```kql
// Find VMs with avg CPU < 5% for 14+ consecutive days
// These are stop/delete candidates — verify with workload owner before actioning
let ThresholdDays = 14;
let CpuThreshold = 5.0;

InsightsMetrics
| where TimeGenerated > ago(14d)
| where Name == "Percentage CPU"
| where Val < CpuThreshold
| summarize 
    AvgCpu = avg(Val),
    MaxCpu = max(Val),
    DaysBelowThreshold = dcount(bin(TimeGenerated, 1d))
    by Computer, _ResourceId
| where DaysBelowThreshold >= ThresholdDays
| extend VMName = extract(@'virtualMachines/(.+)', 1, _ResourceId)
| extend Subscription = extract(@'subscriptions/([^/]+)', 1, _ResourceId)
| project VMName, Subscription, AvgCpu = round(AvgCpu, 1), MaxCpu = round(MaxCpu, 1), DaysBelowThreshold
| order by DaysBelowThreshold desc
```

## PowerShell — Action Script

```powershell
# Stop idle VMs (with confirmation)
# Run AFTER KQL query identifies candidates and workload owners approve

param([string[]]$VMNames, [string]$SubscriptionId)

Set-AzContext -SubscriptionId $SubscriptionId | Out-Null

foreach ($Name in $VMNames) {
    $VM = Get-AzVM -Name $Name -Status -ErrorAction SilentlyContinue
    if ($VM.PowerState -eq 'VM running') {
        Write-Host "Stopping $Name (was running, CPU < 5% for 14+ days)" -ForegroundColor Yellow
        Stop-AzVM -Name $Name -ResourceGroupName $VM.ResourceGroupName -Force -NoWait
    } else {
        Write-Host "Skipping $Name (already $($VM.PowerState))" -ForegroundColor Gray
    }
}
```

## Decision Tree

```mermaid
graph TD
    VM[VM with CPU < 5%<br>for 14+ days] --> Q1{Production?}
    Q1 -->|Yes| Q2{Can it be<br>scheduled?}
    Q1 -->|No| Q3{Still needed?}
    Q2 -->|Yes| SCHED[Schedule shutdown<br>nights + weekends]
    Q2 -->|No| RIGHT[Rightsize to<br>smaller SKU]
    Q3 -->|No| DELETE[Delete VM + disks]
    Q3 -->|Yes| STOP[Stop (deallocate)<br>save 80-100%]
    
    SCHED --> SAVE1[Savings: 60-70%]
    RIGHT --> SAVE2[Savings: 30-50%]
    DELETE --> SAVE3[Savings: 100%]
    STOP --> SAVE4[Savings: 80-100%]
    
    style DELETE fill:#dc2626,color:#fff
    style STOP fill:#d97706,color:#fff
    style SCHED fill:#059669,color:#fff
    style RIGHT fill:#0078D4,color:#fff
```

## Production Track Record

| Engagement | Idle VMs Found | Actioned | Monthly Savings |
|-----------|:---:|:---:|:---:|
| UK Water | 23 | 19 stopped, 4 deleted | £8,200/month |
| EU Insurance | 41 | 28 stopped, 8 deleted, 5 scheduled | £14,600/month |
