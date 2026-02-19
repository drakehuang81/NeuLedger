## Why

The current codebase lacks reusable design system components. This leads to inconsistent UI, duplicate code, and slower development speed. We need to implement the design system components defined in our internal design tool (Pencil) to ensure a consistent and high-quality UI across the application, adhering to the "NeuLedger" design language (Glassmorphism, rounded corners, specific color palette).

## What Changes

We will implement a set of reusable SwiftUI components based on the "Design System — Components" section of the Pencil file. These components will be placed in `Features/Sources/Features/Components` and will include comprehensive SwiftUI Previews to verify their appearance and behavior in isolation.

The following components will be created:
- **TransactionRow**: Determine layout for displaying transaction details.
- **AccountCard**: Standard card for account information.
- **CategoryChip**: Small pill for categories.
- **TagPill**: Small pill for tags or amounts.
- **BalanceDisplay**: Prominent display for total balance.
- **InsightCard**: Card for displaying AI insights.
- **BudgetGauge**: Visual progress indicator for budgets.
- **GlassButton**: Standard action button with glass effect.
- **GlassContainer**: Base container with glass effect.
- **QuickActionBar**: Bottom action bar for quick access.

## Capabilities

### New Capabilities
<!-- Capabilities being introduced. Replace <name> with kebab-case identifier (e.g., user-auth, data-export, api-rate-limiting). Each creates specs/<name>/spec.md -->
- `design-system-components`: Implementation of core UI components (TransactionRow, AccountCard, etc.) with glassmorphism style and SwiftUI previews support.

### Modified Capabilities
<!-- Existing capabilities whose REQUIREMENTS are changing (not just implementation).
     Only list here if spec-level behavior changes. Each needs a delta spec file.
     Use existing spec names from openspec/specs/. Leave empty if no requirement changes. -->
- 

## Impact

- **New Files**: Multiple SwiftUI View files in `Features/Sources/Features/Components/`.
- **Dependencies**: No new external dependencies expected, but will rely on existing `Features` module structure.
- **Preview Provider**: Each component will have a `#Preview` block (or `PreviewProvider`) to facilitate rapid UI development and verification.
