# RI Coverage % — DAX

> **Atomic skill:** Track Reserved Instance coverage ratio for production VMs.
> **Cross-ref:** [`ri-vs-sp-decision/`](../../../reserved-instances/ri-vs-sp-decision/) for when to use RI vs SP

## Measures

```dax
// Total Production VMs
Prod VM Count = 
CALCULATE(
    COUNTROWS('Resources'),
    'Resources'[Environment] = "prod",
    'Resources'[Type] = "Microsoft.Compute/virtualMachines"
)

// VMs Covered by Reservations
RI Covered VMs = 
CALCULATE(
    COUNTROWS('Resources'),
    'Resources'[PricingModel] = "Reservation",
    'Resources'[Environment] = "prod",
    'Resources'[Type] = "Microsoft.Compute/virtualMachines"
)

// RI Coverage %
RI Coverage % = DIVIDE([RI Covered VMs], [Prod VM Count], 0)

// RI Utilisation (hours used / hours purchased)
RI Utilisation % = 
DIVIDE(
    SUM('RIUsage'[UsedHours]),
    SUM('RIUsage'[PurchasedHours]),
    0
)

// Potential Savings (if coverage increased to target)
Potential RI Savings = 
VAR TargetCoverage = 0.80
VAR CurrentOnDemand = CALCULATE(
    [Total Cost],
    'CostExport'[PricingModel] = "OnDemand",
    'CostExport'[MeterCategory] = "Virtual Machines",
    'DimTag'[Environment] = "prod"
)
VAR CurrentCoverage = [RI Coverage %]
VAR GapSpend = CurrentOnDemand * (TargetCoverage - CurrentCoverage)
VAR AvgDiscount = 0.37  // Typical 1-year RI discount
RETURN GapSpend * AvgDiscount

// Coverage target status
Coverage Status = 
VAR Pct = [RI Coverage %]
RETURN IF(Pct >= 0.80, "✅ On Target",
     IF(Pct >= 0.60, "⚠️ Below Target",
     "🔴 Critical"))
```

## Visual Setup

| Visual | Measure | Target |
|--------|---------|:---:|
| Gauge chart | `[RI Coverage %]` | 80% |
| KPI card | `[RI Utilisation %]` | >95% |
| KPI card | `[Potential RI Savings]` | £ projected |
| Status badge | `[Coverage Status]` | ✅ On Target |
