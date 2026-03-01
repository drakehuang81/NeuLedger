## Context

NeuLedger requires an `AnalysisView` to summarize financial health, spending habits, budget progress, and AI-driven insights for the user. Currently, `AnalysisView` is largely a placeholder or empty state. We need to implement a full SwiftUI interface to match the `neuledger-design-system.pen` specifications. The project relies on The Composable Architecture (TCA) for state management and Clean Architecture principles.

## Goals / Non-Goals

**Goals:**
- Implement the UI components for the Analysis dashboard (Summary Card, Pie Chart, Bar Chart, Budget Indicators, and AI Insight Card) as defined in the design specs.
- Provide a responsive layout that displays appropriately on iOS devices.
- Setup the TCA structure (State, Action, Reducer) for `AnalysisFeature` to handle period selection and state transitions (e.g., empty state vs. data state).
- Use Apple's native `Charts` framework for rendering the pie and bar charts.

**Non-Goals:**
- Implementing the actual backend data fetching or AI model integration for insights (this will rely on placeholder/mock data in the UI phase).
- Modifying the existing database schema.
- Implementing deep interactions for charts (e.g., tapping a specific pie slice to drill down into a new list view). For now, rendering the data is sufficient.

## Decisions

- **UI Framework Options**: SwiftUI vs. UIKit
  - *Decision*: **SwiftUI**, as it aligns with the rest of the project and allows for fast iteration on declarative, state-driven UI elements.
- **State Management**: TCA (The Composable Architecture)
  - *Decision*: We will introduce an `AnalysisFeature` reducer containing `State` (currently selected period, financial data mock models) and `Action` (period changed, etc.) to drive the UI cleanly.
- **Charting Library**: Apple `Charts` framework
  - *Decision*: We will use Apple's native `Charts` introduced in iOS 16+. It integrates perfectly with SwiftUI and handles responsive sizing, legends, and styling natively, avoiding heavy third-party dependencies.
- **Component Anatomy**:
  - We will break down the `AnalysisView` into smaller, bite-sized views (`SummaryCardView`, `CategoryPieChartView`, `TrendBarChartView`, `BudgetProgressView`, `AIInsightCardView`). This prevents `AnalysisView` from becoming a massive single struct, making the UI easier to test and maintain.

## Risks / Trade-offs

- **Risk**: The native `Charts` framework might have limitations when attempting complex custom behaviors (like detailed tooltip popovers on tap).
  - *Mitigation*: Stick closely to the built-in annotations and styling options provided by `Charts`. If a design requires extreme customization not supported natively, we may need to slightly simplify the UI to match standard `Charts` capabilities while maintaining the overall aesthetic.
- **Risk**: Mock data structures defined now might not exactly match the actual backend response format later.
  - *Mitigation*: Design the models to be simple abstractions (e.g., `CategoryIncome`, `DailyTrend`). Map backend models to these view models in the TCA environment or interactor layer later.
- **Trade-off**: Hardcoding some of the "glass" styling initially.
  - *Rationale*: We'll implement a reusable glass modifier or background to match the design system, but we must ensure performance isn't degraded if we over-use blur effects in a scrolling `ScrollView`. We will monitor scroll performance and fall back to solid/translucent colors if needed.
