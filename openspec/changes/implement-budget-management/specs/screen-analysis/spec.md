## MODIFIED Requirements

### Requirement: Budget Status Display
The system SHALL display active budgets for categories alongside a progress bar indicating current consumption relative to the available budget threshold, loaded live via `BudgetClient`.

#### Scenario: Displaying category budgets
- **WHEN** there is an active planned budget (retrieved via `fetchActive()`) and the view is presented
- **THEN** a progress gauge displays the aggregated `BudgetGaugeMetrics` computed from the current budget and expenditures
- **AND** 預算進度條與生命週期計算參見 `feature-budgets.md`
- **AND** the gauge visually depicts the spent/limit ratio, and the remaining amount alongside percentage used
