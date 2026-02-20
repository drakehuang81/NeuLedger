
# Tasks: Design Empty States for Dashboard & Analysis

## 1. Design & Assets

- [x] 1.1 Update `neuledger-design-system.pen` to include `EmptyStateView` component variants (Dashboard & Analysis).
- [x] 1.2 Export new design assets if necessary (Using SF Symbols).

## 2. Core Implementation

- [x] 2.1 Implement `EmptyStateView` in `Features/Sources/Features/Components/EmptyStateView.swift`.
- [x] 2.2 Add preview providers for `EmptyStateView` showcasing different variants.

## 3. Feature Integration

- [x] 3.1 Update `DashboardFeature` state to track if transaction list is empty.
- [x] 3.2 Update `DashboardView` to conditionally show `EmptyStateView` instead of transaction list.
- [x] 3.3 Update `AnalysisFeature` state to track if data exists for selected period.
- [x] 3.4 Update `AnalysisView` to conditionally show `EmptyStateView` instead of charts.

## 4. Verification

- [x] 4.1 Verify Dashboard empty state on fresh install (or by clearing data).
- [x] 4.2 Verify Analysis empty state by selecting a future date range.
- [x] 4.3 Ensure dark mode compatibility.
