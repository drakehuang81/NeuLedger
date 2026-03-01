# Analysis Dashboard
**Purpose**: Define the layout, overall structure, and components of the Analysis Dashboard screen in the app.

## Requirements

### Requirement: Layout and Structure
The system SHALL display an Analysis view providing users with an overview of their financial data. It MUST use a standard iOS NavigationStack with a ScrollView for the content and support empty states when no data is present.

#### Scenario: User navigates to Analysis view with no data
- **WHEN** the Analysis view loads and there is no financial data for the selected period
- **THEN** an empty state indicator with a message such as "No data for this period" is displayed, and charts/summaries are hidden

### Requirement: Period Selection
The dashboard SHALL include a segmented control or picker allowing the user to switch between analysis periods (e.g., Week, Month, Year).

#### Scenario: User changes the analysis period
- **WHEN** the user selects a new period from the selector
- **THEN** the dashboard issues an action to update the data state to reflect the selected period's financial summary

### Requirement: Financial Summary Card
The dashboard SHALL display a financial summary card at the top, which MUST show the total Income, total Expense, and Net Balance for the selected period.

#### Scenario: Valid financial data is present
- **WHEN** the Analysis view loads and receives data
- **THEN** the summary card renders the formatted currency strings for Income, Expense, and Net Balance in their respective columns
