# Spec: Screen - Analysis
**Purpose**: Define the layout, overall structure, and components of the Analysis Dashboard screen in the app.

## Requirements

### Requirement: Layout and Structure
The system SHALL display an Analysis view providing users with an overview of their financial data. It MUST use a standard iOS NavigationStack with a ScrollView for the content and support empty states when no data is present.

#### Scenario: User navigates to Analysis view with no data
- **WHEN** the Analysis view loads and there is no financial data for the selected period
- **THEN** an empty state indicator with a message such as "No data for this period" is displayed, and charts/summaries are hidden
- **AND** 提示用戶「此期間無資料」

### Requirement: Period Selection
The dashboard SHALL include a segmented control or picker allowing the user to switch between analysis periods (e.g., Week, Month, Year).

#### Scenario: User changes the analysis period
- **WHEN** the user selects a new period from the selector
- **THEN** the dashboard issues an action to update the data state to reflect the selected period's financial summary
- **AND** 預設為「本月」

### Requirement: Financial Summary Card
The dashboard SHALL display a financial summary card at the top, which MUST show the total Income, total Expense, and Net Balance for the selected period.

#### Scenario: Valid financial data is present
- **WHEN** the Analysis view loads and receives data
- **THEN** the summary card renders the formatted currency strings for Income, Expense, and Net Balance in their respective columns
- **AND** 計算選定期間內的：
    - 總收入 (所有 `.income` 交易的金額總和)
    - 總支出 (所有 `.expense` 交易的金額總和)
    - 淨額 (總收入 - 總支出)
- **AND** 轉帳不計入收入/支出

### Requirement: Expense Pattern Distribution (Pie Chart)
The system SHALL render a pie chart representing the proportion of expenses for each transaction category.

#### Scenario: Visualising categorized expenditures
- **WHEN** there are categorized expenses for the current period
- **THEN** a segmented pie chart is displayed, with slices indicating primary category proportions (e.g., Food, Transport)
- **AND** 點擊某一塊可查看該分類的交易明細

### Requirement: Daily Spending Trend (Bar Chart)
The system SHALL visualize the historical daily or weekly spending patterns via a bar chart.

#### Scenario: Chart rendering daily values
- **WHEN** daily spend data is provided over a week or month
- **THEN** the system generates a bar chart mapping each specific date mapping to an expense amount in standard currency layout
- **AND** 使用 Swift Charts

### Requirement: Budget Status Display
The system SHALL display predefined budgets for categories alongside a progress bar indicating current consumption relative to the available budget threshold.

#### Scenario: Displaying category budgets
- **WHEN** there is a planned budget and tracked expenditures for that category
- **THEN** a progress gauge displays showing the name of the budget, progress bar visually depicting the spent/limit ratio, and the remaining amount alongside percentage used
- **AND** 預算進度條與生命週期計算參見 `feature-budgets.md`

### Requirement: Period Snapshot Insights (AI)
The system SHALL present AI-generated insights regarding recent spending, analyzing key trends or anomalies in the ledger data.

#### Scenario: Displaying actionable AI advice
- **WHEN** there are identifiable spending anomalies (e.g., peak spending days) or optimization opportunities from AI models
- **THEN** an AI insight card is populated with a digestible recommendation highlighting the pattern and offering cost-saving advice
- **AND** 洞察使用 `LanguageModelSession` + `QueryTransactionsTool` 生成
- **AND** 可被使用者關閉/dismiss
