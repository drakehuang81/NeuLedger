## 1. Feature Architecture setup

- [x] 1.1 Create `DashboardFeature.swift` with basic TCA State, Action, and Reducer structure. Include empty state placeholder flags and `@PresentationState` for the `AddTransaction` feature.
- [x] 1.2 Define `DashboardFeature.Delegate` actions for routing (`seeAllTransactionsTapped`, `accountTapped`, `transactionTapped`).
- [x] 1.3 Add dependencies for `AccountClient`, `TransactionClient`, and `AIClient` in `DashboardFeature`.

## 2. State Aggregation & AI Insights Logic

- [x] 2.1 Implement `.onAppear` / `.task` effect to start an `AsyncStream` (or publisher) observation for Accounts and Transactions.
- [x] 2.2 Implement logic to compute the total global balance and slice the top accounts (sorted by balance, descending) and top 3 recent transactions (sorted by date, descending) whenever the stream emits new data.
- [x] 2.3 Implement the asynchronous `.fetchAIInsight` effect with a caching strategy. Ensure it falls back gracefully if the API call fails or times out.
- [x] 2.4 Invalidate the AI Insight cache and trigger a new fetch when new transaction data is detected by the stream.
- [x] 2.5 Implement `.pulledToRefresh` interaction to refresh data streams manually and force a new AI Insight fetch.

## 3. Dashboard UI Construction

- [x] 3.1 Create `DashboardScreen.swift` and connect it to the `DashboardFeature` store using TCA View paradigms.
- [x] 3.2 Layout the top header and the `refBalance` component, displaying the computed total balance using the `$--font-display` scaling.
- [x] 3.3 Add the `refActions` component below the balance. Include the quick action button to start the add transaction flow.
- [x] 3.4 Integrate the `refInsight` component. Implement the `.redacted(reason: .placeholder)` skeleton view for when the insight is loading.
- [x] 3.5 Construct the "My Wallets" (Accounts) horizontal scroll section using `AccountCard`. Add the global "EmptyStateView" if the user has NO accounts or wallets. 
- [x] 3.6 Construct the "Recent Transactions" vertical list using `TransactionRow`. Add an "EmptyStateView" placeholder if the user has 0 transactions (but has at least one account).
- [x] 3.7 Add the `.refreshable` modifier to the wrapping `ScrollView` to dispatch the `.pulledToRefresh` action.
- [x] 3.8 Attach the `.sheet` (or `.fullScreenCover`) modifier for `$addTransaction` presentation state.

## 4. Main Navigation Integration

- [x] 4.1 Update `MainTabFeature.swift` to include `DashboardFeature` in its composite state and reducer. Ensure the Dashboard is the default selected tab.
- [x] 4.2 In `MainTabFeature`, intercept `DashboardFeature.Action.delegate` actions. Map `.seeAllTransactionsTapped`, `.accountTapped`, and `.transactionTapped` to the appropriate Tab changes.
- [x] 4.3 Update the `MainTabView` to inject the `DashboardScreen` correctly mapping to the current tab bar structure. Ensure the sticky floating `quickActionBar` overlays correctly.

## 5. Testing & Validation

- [x] 5.1 Write a `DashboardFeatureTests` suite verifying that the continuous stream updates state correctly (balances, accounts, transactions).
- [x] 5.2 Write a test case verifying the AI Insight cache invalidation when a new transaction is recorded.
- [x] 5.3 Write a test case verifying `.pulledToRefresh` forces an AI Insight update.
- [x] 5.4 Test routing assertions ensuring `.delegate` actions are published upon corresponding user interactions.
