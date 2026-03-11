## MODIFIED Requirements

### Requirement: Data Management Navigation Section
Provide navigation access to core data settings for configuring Accounts, Categories, Budgets, and Tags independently.

#### Scenario: Accessing Management Views
- **WHEN** the user views the main Settings screen
- **THEN** the existing "管理" section SHALL contain tappable rows that push the management screens onto the navigation stack via `NavigationLink(value: SettingsRoute.xxx)`
- **AND** the rows for Account, Category, Budget, and Tag management SHALL use `SettingsRoute` cases to push their respective management screens
- **AND** the "預算設定" row SHALL use `NavigationLink(value: SettingsRoute.budgetManagement)` to push the `BudgetManagementView`，取代現有的佔位符
