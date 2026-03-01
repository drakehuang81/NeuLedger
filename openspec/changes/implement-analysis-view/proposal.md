## Why

Users currently lack a comprehensive overview of their financial health. While transactions are recorded, there is no centralized place to visualize spending habits, track budget progress, or view high-level summaries. Implementing the Analysis view provides this crucial missing link, leveraging visual charts and AI-powered insights to help users better understand their finances over customized periods.

## What Changes

- Implement the main UI foundation for the `AnalysisView` with support for different states (has data vs empty state).
- Add a period selector (e.g., this week, this month, this year).
- Implement a financial summary card displaying total income, expenses, and net balance.
- Add an expense category distribution via a pie chart.
- Add daily spending trends via a bar chart.
- Implement budget progress indicators showing remaining amounts and percentages.
- Introduce an AI Insight card that outlines smart recommendations and summaries from the personalized AI ledger.

## Capabilities

### New Capabilities

- `analysis-dashboard`: Core framework of the Analysis tab, including the period selector (segment picker), empty states, and the financial summary card (income, expense, and net values).
- `analysis-charts`: Visual graphical representation of financial data, including the expense categories (pie chart) and daily trend (bar chart).
- `analysis-budgets`: Display of user budgets for specific categories alongside their current spending progress.
- `analysis-ai-insights`: A card displaying AI-driven summaries and actionable budgeting recommendations to the user based on their data.

### Modified Capabilities

- None

## Impact

- **UI/UX**: Introduces multiple new SwiftUI components and layouts based on the `neuledger-design-system.pen` specifications.
- **Dependencies**: May require reliance on a charting library (e.g., underlying SwiftUI `Charts` framework) to render the pie and bar charts.
- **State Management**: Modifies the `AnalysisView` to consume different states and dummy data sources to present these UI components.
