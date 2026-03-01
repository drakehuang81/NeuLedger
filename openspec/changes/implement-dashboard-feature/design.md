## Context

NeuLedger requires a Dashboard to serve as the default home screen. The goal is to provide users an immediate snapshot of their financial state by combining data from multiple domains (transactions, accounts) and enhancing it with generative AI insights. The app is built on The Composable Architecture (TCA), relying on Clean Architecture principles and modular Domain clients.

Currently, the app has separate features/clients for Transactions, Accounts, and AI Integration, but no centralized feature orchestrating data fetching across these domains to present an aggregated view.

## Goals / Non-Goals

**Goals:**
- Implement `DashboardFeature` reducer to aggregate data from Accounts and Transactions domains.
- Display a unified SwiftUI view (`screen-dashboard`) using the `neuledger-design-system` components.
- Gracefully handle empty states for new users (no accounts, no transactions).
- Handle AI Insight "cold starts" and cache/reload mechanisms via Pull-to-Refresh.
- Support safe and type-driven routing for presenting deep-link actions (e.g., navigating to account details, opening the "Add Transaction" sheet).

**Non-Goals:**
- Modifying the underlying data models or storage (`swiftdata-persistence`) for Accounts and Transactions.
- Implementing the "Add Transaction" logic itself (Dashboard only triggers the navigation/presentation).
- Implementing pagination for transactions inside the dashboard (it only shows the top 3).

## Decisions

**1. TCA State Aggregation**
*Decision:* `DashboardFeature` will observe changes via a long-running `Effect` (e.g., `AsyncStream` observation) from `AccountClient` and `TransactionClient` starting on `.task` or `.onAppear`.
*Rationale:* Dashboard shouldn't hold the absolute source of truth but rather a derived, read-only snapshot of the data. Continuous observation ensures the dashboard gracefully remains in sync with the underlying databases automatically, while manual fetches occur via `.pulledToRefresh`.

**2. AI Insights Orchestration**
*Decision:* Fetch the AI insight asynchronously, separate from the primary data load. If it fails, fallback gracefully rather than blocking the whole screen.
*Rationale:* LLM API calls can be slow or fail. We shouldn't block the rendering of the user's balances and recent transactions. If it's a cold start (no data) or API fails, we display a fallback UI or simply a friendly "Record your first transaction" message.

**3. Routing and Navigation**
*Decision:* Use `@PresentationState` for explicitly managed modal presentations (like presenting the `AddTransactionFeature` sheet). For navigating to other tabs (like full Accounts or Transactions list), the feature will emit `Delegate` actions (e.g., `delegate(.seeAllTransactionsTapped)`).
*Rationale:* Ensures decoupling. The parent feature (e.g., `MainTabFeature`) will interpret these delegate actions and perform the actual tab switch or deep-link navigation, while `@PresentationState` keeps local sheets safe and testable.

**4. Pull-to-Refresh Strategy**
*Decision:* Implement SwiftUI's `.refreshable` modifier bound to a `.pulledToRefresh` TCA action. This action will explicitly return an `Effect` that merges the fetches for Balance, Transactions, and a forced refresh of AI Insights.
*Rationale:* Gives users explicit control to reload Cloud/AI data without forcing background polling.

**5. Caching and AI API Cost Control**
*Decision:* To prevent excessive LLM API calls, `DashboardFeature` will employ a caching strategy for AI Insights, only requesting a new insight when a significant state change occurs (e.g., a new transaction is recorded) or when the user explicitly triggers a pull-to-refresh.
*Rationale:* Reduces latency and API costs while maintaining relevance.

## Risks / Trade-offs

- **Risk:** AI Insight generation takes too long and causes a janky UX or times out.
  - *Mitigation:* We will employ a `.cancellable` effect with a deterministic timeout. Provide a skeleton loader state (`isLoadingInsight`) on the `refInsight` card.
- **Risk:** UI performance drop due to `background_blur` operations on multiple glassmorphic components concurrently in a `ScrollView`.
  - *Mitigation:* Test view rendering in Instruments. If needed, optimize `GlassContainer` materials or use `.drawingGroup()` around static background elements. Implement a Skeleton View (`.redacted(reason: .placeholder)`) during the initial data load to improve perceived performance and keep the UI responsive.
- **Risk:** Data inconsistency if a transaction is added but the dashboard isn't updated.
  - *Mitigation:* Ensure `DashboardFeature` listens to an `AsyncStream` of updates from the underlying clients, or triggers a refresh on successful dismissal of the `AddTransaction` presentation.
