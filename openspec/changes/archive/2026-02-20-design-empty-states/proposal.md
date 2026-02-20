
# Proposal: Design Empty States for Dashboard & Analysis

## Why
Currently, the **Dashboard** and **Analysis** screens lack proper empty states for users with no data (e.g., fresh install) or no data in the selected period. This can lead to confusion and a perception that the app is broken or unfinished. We need clear, friendly, and actionable empty states to guide users.

## What Changes
1.  **Dashboard Empty State**:
    *   Design a welcoming empty state for the Dashboard when no transactions exist.
    *   Direct the user to the "Add Transaction" action.
    *   Use a friendly illustration (likely composed of SF Symbols) and encouraging text.

2.  **Analysis Empty State**:
    *   Design an empty state for the Analysis screen when the selected period has no data.
    *   Display a placeholder for charts to maintain layout stability or a centered message.
    *   Clear indication that "No transactions found for this period".

3.  **Update Design System**:
    *   Formalize the `EmptyStateView` component in the `.pen` file to ensure consistency across the app.
    *   Define variants (e.g., "No Transactions", "No Search Results", "Offline").

## Capabilities

### Modified Capabilities
<!-- Existing capabilities whose REQUIREMENTS are changing. -->
- `design-system`: Add specific requirements for Empty State components and their variants.
- `app-features`: Update Dashboard and Analysis requirements to specify behavior when data is missing.

## Impact
- **Design**: Updates to `neuledger-design-system.pen` to include empty state designs and specific screen mockups.
- **Code**:
    - Implementation of reusable `EmptyStateView`.
    - Updates to `DashboardView` and `AnalysisView` to handle empty data states.
