## ADDED Requirements

### Requirement: Expense Pattern Distribution
The system SHALL render a pie chart representing the proportion of expenses for each transaction category.

#### Scenario: Visualising categorized expenditures
- **WHEN** there are categorized expenses for the current period
- **THEN** a segmented pie chart is displayed, with slices indicating primary category proportions (e.g., Food, Transport)

### Requirement: Daily Spending Trend
The system SHALL visualize the historical daily or weekly spending patterns via a bar chart.

#### Scenario: Chart rendering daily values
- **WHEN** daily spend data is provided over a week or month
- **THEN** the system generates a bar chart mapping each specific date mapping to an expense amount in standard currency layout
