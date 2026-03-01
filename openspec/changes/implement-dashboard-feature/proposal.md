## Why

The NeuLedger application needs a central hub where users can get an immediate snapshot of their financial health. This dashboard will provide an aggregated view of total balances, recent transactions, top accounts, and AI-driven spending insights to quickly engage the user upon opening the app.

## What Changes

- Introduce the primary Dashboard screen containing the user's total balance and income/expense breakdown.
- Add an AI Insights card to offer immediate, context-aware suggestions directly on the home page.
- Add a quick-action "記帳" (Add Transaction) button for frictionless data entry.
- Display a horizontal scroll of top/active wallets (accounts) with a link to see all.
- Present a list of the 3 most recent transactions.
- Handle empty states for new users without existing accounts or transactions.
- Handle the cold start logic for the AI Insights card.
- Incorporate pull-to-refresh capabilities to reload aggregate data and update AI insights.
- Provide clear error handling and fallback UI for failed data fetches (e.g. AI API failures).
- Integrate the Screen into the Main Navigation Flow.

## Capabilities

### New Capabilities
- `feature-dashboard`: Business logic for aggregating total global balance (from all active accounts), fetching the top 3 most recent transactions, summarizing the top accounts, and requesting an AI Insight contextually.
- `screen-dashboard`: SwiftUI layout and composition for the Dashboard based on the design system, including the Glassmorphism balance card, insight card, and bottom split tab navigation layout.

### Modified Capabilities
- `screen-main-navigation`: Update the main navigation spec so the Dashboard serves as the default root view in the app's primary tab structure.

## Impact

- **UI Frameworks:** Will heavily use existing `refBalance`, `refActions`, `refInsight`, `quickActionBar` and `GlassContainer` components from the design system.
- **Dependencies:** Interacts with `feature-transactions`, `feature-accounts`, and `ai-integration` clients to orchestrate the fetch and compilation of the dashboard aggregate state.
- **TCA Store & Routing:** Introduces a new `DashboardFeature` reducer encapsulating the state and effects for loading the dashboard data. It will also manage navigation routes (e.g., presenting the Add Transaction sheet, navigating to the Full Transaction List, or Account details) using `@PresentationState` or `Path`.
- **Testing:** Requires unit testing for the new `DashboardFeature` reducer to ensure that multi-dependency state aggregation, error handling, and routing logic work correctly.
