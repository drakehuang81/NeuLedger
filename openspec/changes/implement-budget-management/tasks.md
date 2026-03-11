## 1. Budget Management Core Feature

- [ ] 1.1 Create `BudgetFormFeature` reducer (State, Action, logic) for creating and editing a budget
- [ ] 1.2 Create `BudgetManagementFeature` reducer (State, Action, logic) with a list of budgets and a `PresentationState` for the form sheet
- [ ] 1.3 Create `BudgetFormView` UI component with validation and fields (name, amount, period, startDate, categoryId)
- [ ] 1.4 Create `BudgetRow` UI component to display a budget's summary and its active toggle
- [ ] 1.5 Create `BudgetManagementView` UI component integrating the list and sheet presentation

## 2. Settings Navigation Integration

- [ ] 2.1 Add `.budgetManagement` case to `SettingsRoute` enum in `SettingsView.swift`
- [ ] 2.2 Add `BudgetManagementView` handling in `navigationDestination(for: SettingsRoute.self)`
- [ ] 2.3 Replace the "預算設定" placeholder with `NavigationLink(value: SettingsRoute.budgetManagement)`

## 3. Analysis View Integration

- [ ] 3.1 Update `AnalysisFeature.State` to hold `activeBudget` or `budgetMetrics`
- [ ] 3.2 Update `AnalysisFeature` reducer to call `budgetClient.fetchActive()` alongside other initial data fetch operations
- [ ] 3.3 Calculate and update `BudgetGaugeMetrics` within `AnalysisFeature` based on the fetched active budget and current expenditures
- [ ] 3.4 Integrate the calculated metrics into the `BudgetGauge` rendering in `AnalysisView`
- [ ] 3.5 Ensure data is refreshed appropriately so toggling a budget in Settings is reflected when returning to Analysis
