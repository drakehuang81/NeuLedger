## ADDED Requirements

### Requirement: Render Dashboard Components
The `screen-dashboard` MUST construct its layout by composing the defined `neuledger-design-system` UI components (e.g., `refBalance`, `refActions`, `refInsight`, `quickActionBar`).

#### Scenario: Rendering the aggregated balance
- **WHEN** the `DashboardFeature` provides a positive total balance
- **THEN** the `refBalance` card renders it using `$--font-display` and the corresponding localized currency formatter.

#### Scenario: Rendering the AI Insights Card with skeleton
- **WHEN** the `DashboardFeature` indicates the AI insight is currently fetching
- **THEN** the `refInsight` card applies a `.redacted(reason: .placeholder)` modifier to display a loading skeleton view.

#### Scenario: Rendering the Top Accounts Scroll
- **WHEN** the `DashboardFeature` provides a non-empty list of active accounts
- **THEN** a horizontally scrollable sequence of `AccountCard`s is displayed under the "My Wallets" section.

#### Scenario: Rendering the Recent Transactions List
- **WHEN** the `DashboardFeature` provides up to 3 recent transactions
- **THEN** they are displayed sequentially utilizing the `TransactionRow` component.

#### Scenario: Rendering the Quick Action Bar
- **WHEN** the view renders the bottom sticky/fixed area
- **THEN** the `quickActionBar` component is displayed
- **AND** tapping the add button triggers an action intended to show the add transaction sheet (e.g., `.addTransactionButtonTapped`).

### Requirement: Visual Handling of Empty States
When the `DashboardFeature` returns empty accounts or transactions, the `screen-dashboard` MUST display user-friendly placeholder elements encouraging action.

#### Scenario: No recent transactions
- **WHEN** there are no transactions
- **THEN** an `EmptyStateView` placeholder is displayed in place of the `TransactionRow` list, asking the user to add their first transaction.

#### Scenario: No accounts available
- **WHEN** there are no active accounts
- **THEN** an `EmptyStateView` placeholder is displayed in place of the "My Wallets" section, asking the user to add their first account/wallet.

### Requirement: Interactive Pull-to-Refresh
The `screen-dashboard` MUST wrap its primary content in a `ScrollView` that supports the SwiftUI `.refreshable` modifier.

#### Scenario: User pulls down on the ScrollView
- **WHEN** the user executes a pull-to-refresh swipe gesture
- **THEN** the `.pulledToRefresh` TCA action is sent to the `DashboardFeature`.
- **AND** the loading indicator remains visible until the `DashboardFeature` signals completion of its refresh `Effect`.

### Requirement: Presentation Modals
The `screen-dashboard` MUST connect the feature's `@PresentationState` to corresponding SwiftUI modal modifiers (e.g., `.sheet` or `.fullScreenCover`).

#### Scenario: Displaying Add Transaction Sheet
- **WHEN** the `DashboardFeature` state's `$addTransaction` becomes non-nil
- **THEN** a `.sheet` modifier presents the `AddTransactionView` bound to the presentation store.
