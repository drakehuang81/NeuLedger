
# Design: Empty States for Dashboard & Analysis

## Context
The **Dashboard** and **Analysis** screens of NeuLedger currently display empty lists or undefined states when no data is available. This negatively impacts the user experience, especially during onboarding or when specific filters yield no results. We need to implement a consistent and guiding empty state experience.

## Goals / Non-Goals

**Goals:**
1.  Design and implement a reusable `EmptyStateView` component in the Design System.
2.  Update `DashboardView` to display a welcoming empty state when no transactions exist.
3.  Update `AnalysisView` to display a contextual empty state when no data exists for the selected period.
4.  Update the `.pen` design file to reflect these changes visually.

**Non-Goals:**
1.  Implementing empty states for screens other than Dashboard and Analysis in this change (though the component will be reusable).
2.  Changing the core data loading logic beyond handling empty results.

## Decisions

### 1. Reusable `EmptyStateView` Component
*   **Decision**: Create a configurable `EmptyStateView` that accepts an SF Symbol, title, description, and an optional action closure.
*   **Rationale**: Ensures visual consistency across the app and reduces code duplication.
*   **Alternatives**: Implementing ad-hoc empty states in each view (inconsistent, harder to maintain).

### 2. Illustration Strategy
*   **Decision**: Use SF Symbols combined with shapes (e.g., circles behind symbols) or custom asset catalog images if available.
*   **Rationale**: SF Symbols fit the native iOS aesthetic of NeuLedger and scale well.
*   **Alternatives**: Custom vector illustrations (require design resources), Lottie animations (heavy dependency).

### 3. Dashboard Empty State Specifics
*   **Decision**: Prompt the user to "Add First Transaction".
*   **Interaction**: Tapping the action button opens the "Add Transaction" sheet directly.

### 4. Analysis Empty State Specifics
*   **Decision**: Inform the user "No data for this period".
*   **Interaction**: No specific action, or perhaps suggest changing the date range.

## Risks / Trade-offs
*   **Risk**: Overcomplicating the empty state with too many variants.
    *   **Mitigation**: Start with a generic, flexible component and specialize only if necessary.
*   **Risk**: Visual clash with existing content if not properly centered/spaced.
    *   **Mitigation**: Design in `.pen` file first to verify layout.

## Migration Plan
1.  Update `neuledger-design-system.pen` with new empty state designs.
2.  Implement `EmptyStateView` in code.
3.  Integrate into `DashboardView` and `AnalysisView`.
