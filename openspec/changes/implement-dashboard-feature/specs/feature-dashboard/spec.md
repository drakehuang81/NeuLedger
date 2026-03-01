## ADDED Requirements

### Requirement: Dashboard Feature State Aggregation
The feature MUST aggregate data from multiple domain clients (`AccountClient`, `TransactionClient`) to build a single read-only snapshot representing the user's dashboard state.

#### Scenario: Successful data aggregation
- **WHEN** the `DashboardFeature` initializes or receives a refresh action
- **THEN** it subscribes to an `AsyncStream` (or similar observing mechanism) for accounts and transactions
- **AND** updates its local state with the computed total balance, top accounts (sorted by balance descending), and top 3 recent transactions (sorted by date descending).

### Requirement: AI Insights Generation and Caching
The feature MUST fetch contextual AI insights asynchronously via the `AIClient` and cache them to prevent excessive API calls.

#### Scenario: Cold start with AI Insight
- **WHEN** the dashboard loads for the first time or after the cache expires/invalidates
- **THEN** it displays a loading skeleton for the insight card
- **AND** makes a request to `AIClient`
- **AND** updates the insight card with the result upon success.

#### Scenario: Triggering insight refresh via pull-to-refresh
- **WHEN** the user manually triggers a pull-to-refresh action
- **THEN** the cache is invalidated
- **AND** a new request is made to the `AIClient`.

#### Scenario: AI Cache invalidation on new data
- **WHEN** the underlying data stream (e.g., `TransactionClient`) emits a new or updated record
- **THEN** the `DashboardFeature` invalidates the currently cached AI Insight
- **AND** automatically fetches a new updated insight to reflect the latest financial state.

#### Scenario: AI API failure fallback
- **WHEN** the request to `AIClient` fails (e.g., timeout or network error)
- **THEN** the feature must catch the error
- **AND** display a friendly fallback message or hide the AI Insight card rather than blocking the dashboard.

### Requirement: Empty State Handling
The feature MUST detect when the user has no accounts or records and return an appropriate empty state.

#### Scenario: New user onboarding (No data at all)
- **WHEN** the aggregated data returns 0 accounts and 0 transactions
- **THEN** the feature state reflects a global empty state
- **AND** the UI components will be instructed to show empty placeholders and onboarding prompts (e.g., "Record your first transaction").

#### Scenario: User has accounts but no transactions
- **WHEN** the aggregated data returns 1 or more accounts, but 0 transactions
- **THEN** the feature state reflects an empty state under transactions only
- **AND** the UI components will be instructed to show the accounts list, but display a transaction placeholder (e.g., "No transactions yet").

### Requirement: Navigation and Routing Delegation
The feature MUST handle intent actions for navigation explicitly without holding destination logic, using `Delegate` actions for cross-tab routing and `@PresentationState` for local modals.

#### Scenario: Navigating to Full Transaction List
- **WHEN** the user taps the "See All" button on the recent transactions list
- **THEN** the feature emits a `delegate(.seeAllTransactionsTapped)` action.

#### Scenario: Navigating to Account Details
- **WHEN** the user taps an individual `AccountCard`
- **THEN** the feature emits a `delegate(.accountTapped(Account.ID))` action.

#### Scenario: Navigating to Transaction Details
- **WHEN** the user taps an individual `TransactionRow`
- **THEN** the feature emits a `delegate(.transactionTapped(Transaction.ID))` action.

#### Scenario: Presenting Add Transaction Modal
- **WHEN** the user taps the "Add Transaction" quick action button
- **THEN** the feature updates its `@PresentationState` to present the `AddTransactionFeature`.
