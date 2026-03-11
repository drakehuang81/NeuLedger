## ADDED Requirements

### Requirement: 預算管理列表（Budget List）
The system SHALL display a list of all budgets the user has created.

#### Scenario: View existing budgets
- **WHEN** the user navigates to the Budget Management screen
- **THEN** a list of all defined budgets is displayed, showing their name, amount, period (BudgetPeriod), and active status (isActive)
- **AND** the list is sorted alphabetically or by creation date
- **AND** each row can be tapped to edit the budget

#### Scenario: Empty state
- **WHEN** there are no budgets defined
- **THEN** an empty state view is displayed, encouraging the user to create their first budget

### Requirement: 新增/編輯預算（Budget Form）
The system SHALL provide a form for creating new budgets and editing existing ones.

#### Scenario: Create new budget
- **WHEN** the user taps the "Add" button in the Budget Management screen
- **THEN** a sheet is presented with fields for `name`, `amount`, `period` (BudgetPeriod picker), `startDate`, and `categoryId` (optional category picker; nil = global budget)
- **AND** the form enforces that `name` cannot be empty and `amount` must be greater than zero
- **AND** saving the form calls the `budgetClient.add` method
- **AND** the list is refreshed upon successful creation

#### Scenario: Edit existing budget
- **WHEN** the user taps an existing budget in the list
- **THEN** a form is presented pre-filled with the budget's current details
- **AND** the form enforcing validation rules
- **AND** saving the form calls the `budgetClient.update` method
- **AND** the list is refreshed upon successful update

### Requirement: 啟用/停用預算切換（Toggle Active Status）
The system SHALL allow users to quickly toggle the active status of a budget directly from the list or detail view.

#### Scenario: Toggle budget status
- **WHEN** the user switches the active toggle for a budget
- **THEN** the system immediately updates the `isActive` property via `budgetClient.update`
- **AND** the updated status is reflected in the UI and propagated to other features immediately
