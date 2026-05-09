# Power BI — DAX Measures for Azure Cost Analytics

> Production DAX patterns from Power BI cost dashboards built for European insurance and UK utilities clients.

## Calendar & Date Intelligence

```dax
// Date table — required for all time-intelligence measures
DateTable = 
ADDCOLUMNS(
    CALENDARAUTO(),
    "Year", YEAR([Date]),
    "Month", MONTH([Date]),
    "MonthName", FORMAT([Date], "MMM"),
    "YearMonth", FORMAT([Date], "YYYY-MM"),
    "Quarter", "Q" & CEILING(MONTH([Date])/3, 1),
    "DayOfWeek", WEEKDAY([Date], 2),
    "IsCurrentMonth", IF(
        EOMONTH([Date], 0) = EOMONTH(TODAY(), 0), 
        TRUE(), FALSE()
    ),
    "IsPreviousMonth", IF(
        EOMONTH([Date], 0) = EOMONTH(EOMONTH(TODAY(), -1), 0), 
        TRUE(), FALSE()
    )
)
```

## Core Cost Measures

```dax
// Total Cost — the base measure
Total Cost = SUM('CostExport'[Cost])

// Current Month Spend
Current Month Spend = 
CALCULATE(
    [Total Cost],
    FILTER(ALL('DateTable'), 'DateTable'[IsCurrentMonth] = TRUE())
)

// Previous Month Spend
Previous Month Spend = 
CALCULATE(
    [Total Cost],
    FILTER(ALL('DateTable'), 'DateTable'[IsPreviousMonth] = TRUE())
)

// Month-over-Month Change (£)
MoM Change (£) = [Current Month Spend] - [Previous Month Spend]

// Month-over-Month Change (%)
MoM Change (%) = 
DIVIDE(
    [MoM Change (£)], 
    [Previous Month Spend], 
    0
)
```

## Forecasting & Projection

```dax
// Daily Average Spend (current month)
Daily Avg Spend = 
VAR DaysElapsed = DATEDIFF(
    CALCULATE(MIN('DateTable'[Date]), 'DateTable'[IsCurrentMonth] = TRUE()),
    TODAY(),
    DAY
) + 1
RETURN DIVIDE([Current Month Spend], DaysElapsed, 0)

// Projected Monthly Spend (linear extrapolation)
Projected Monthly Spend = 
VAR DaysInMonth = DAY(EOMONTH(TODAY(), 0))
RETURN [Daily Avg Spend] * DaysInMonth

// Projected Annual Spend (based on current run rate)
Projected Annual Spend = [Projected Monthly Spend] * 12

// Budget Remaining
Budget Remaining = 
VAR Budget = SUM('Budgets'[Amount])
RETURN Budget - [Current Month Spend]

// Budget Utilisation %
Budget Utilisation % = 
DIVIDE([Current Month Spend], SUM('Budgets'[Amount]), 0)
```

## Cost Allocation

```dax
// Cost by Environment
Cost by Environment = 
CALCULATE(
    [Total Cost],
    VALUES('Resources'[Environment])
)

// Cost by Cost Centre
Cost by Cost Centre = 
CALCULATE(
    [Total Cost],
    VALUES('Resources'[CostCentre])
)

// Unallocated Cost (missing tags)
Unallocated Cost = 
CALCULATE(
    [Total Cost],
    FILTER('Resources', ISBLANK('Resources'[CostCentre]) || 'Resources'[CostCentre] = "")
)

// Unallocated Cost %
Unallocated Cost % = DIVIDE([Unallocated Cost], [Total Cost], 0)
```

## RI & Savings Plan Analysis

```dax
// RI Coverage % (VMs covered by RIs / Total VMs)
RI Coverage % = 
VAR RICoveredVMs = CALCULATE(
    COUNTROWS('Resources'),
    'Resources'[IsRICovered] = TRUE(),
    'Resources'[Type] = "Microsoft.Compute/virtualMachines"
)
VAR TotalVMs = CALCULATE(
    COUNTROWS('Resources'),
    'Resources'[Type] = "Microsoft.Compute/virtualMachines"
)
RETURN DIVIDE(RICoveredVMs, TotalVMs, 0)

// RI Utilisation % (hours used / hours purchased)
RI Utilisation % = 
DIVIDE(
    SUM('RIUsage'[UsedHours]),
    SUM('RIUsage'[PurchasedHours]),
    0
)

// Savings Plan Coverage %
SP Coverage % = 
VAR SPCoveredSpend = CALCULATE(
    [Total Cost],
    'CostExport'[MeterSubCategory] = "Savings Plan"
)
RETURN DIVIDE(SPCoveredSpend, [Total Cost], 0)

// Potential RI Savings (if coverage increased to 80%)
Potential RI Savings = 
VAR TargetCoverage = 0.80
VAR CurrentOnDemandVMCost = CALCULATE(
    [Total Cost],
    'CostExport'[PricingModel] = "OnDemand",
    'CostExport'[MeterCategory] = "Virtual Machines"
)
VAR CurrentCoverage = [RI Coverage %]
VAR GapSpend = CurrentOnDemandVMCost * (TargetCoverage - CurrentCoverage)
VAR AvgRIDiscount = 0.35  // Typical 1-year RI discount ~35%
RETURN GapSpend * AvgRIDiscount
```

## KPI Cards

```dax
// Top-level KPI — Total Annual Run Rate
Annual Run Rate = [Projected Annual Spend]

// Cost per Workload (unit economics)
Cost per Workload = 
DIVIDE(
    [Total Cost],
    DISTINCTCOUNT('Resources'[Workload]),
    0
)

// Savings Realised This Month (£)
Savings This Month = 
CALCULATE(
    SUM('Optimizations'[RealisedSavings]),
    'Optimizations'[Status] = "Completed",
    FILTER(ALL('DateTable'), 'DateTable'[IsCurrentMonth] = TRUE())
)
```

## Visual Layout Recommendations

| Card Position | Measure | Format |
|:---|:---|:---|
| Hero KPI 1 | Projected Annual Spend | £#,##0 |
| Hero KPI 2 | MoM Change (%) | +0.0%;-0.0% |
| Hero KPI 3 | Budget Utilisation % | 0.0% |
| Hero KPI 4 | RI Coverage % | 0.0% |
| Chart 1 | Total Cost by Month (line) | — |
| Chart 2 | Cost by Department (bar) | — |
| Chart 3 | Top 10 Resource Groups (bar) | — |
| Chart 4 | Unallocated Cost trend (line) | — |
| Table | All subscriptions with budget status | — |
