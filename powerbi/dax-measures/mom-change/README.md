# Month-over-Month Change — DAX

> **Atomic skill:** The core cost tracking measure — are we spending more or less than last month?
> **Cross-ref:** [`star-schema/`](../../dataset-schema/star-schema/) for the data model this uses

## Measures

```dax
// Current Month Spend
Current Month Spend = 
CALCULATE(
    [Total Cost],
    FILTER(ALL('DimDate'), 'DimDate'[IsCurrentMonth] = TRUE())
)

// Previous Month Spend
Previous Month Spend = 
CALCULATE(
    [Total Cost],
    FILTER(ALL('DimDate'), 'DimDate'[IsPreviousMonth] = TRUE())
)

// MoM Change (£)
MoM Change (£) = [Current Month Spend] - [Previous Month Spend]

// MoM Change (%)
MoM Change (%) = 
VAR Prev = [Previous Month Spend]
RETURN IF(Prev = 0, BLANK(), DIVIDE([MoM Change (£)], Prev, 0))

// Conditional formatting value
MoM Trend = 
VAR Change = [MoM Change (%)]
RETURN IF(Change > 0.05, "📈 Increasing", 
     IF(Change < -0.05, "📉 Decreasing", "➡️ Stable"))
```

## Visual Card Setup

| Card | Measure | Format | Conditional |
|------|---------|--------|------------|
| Current Spend | `[Current Month Spend]` | £#,##0 | — |
| Last Month | `[Previous Month Spend]` | £#,##0 | — |
| Change (£) | `[MoM Change (£)]` | +£#,##0;-£#,##0 | Green if negative (saving) |
| Change (%) | `[MoM Change (%)]` | +0.0%;-0.0% | Red if >0%, Green if <0% |
| Trend | `[MoM Trend]` | Text | Emoji indicator |
