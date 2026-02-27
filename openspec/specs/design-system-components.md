## ADDED Requirements

### Requirement: Design System Components Implementation

The application MUST provide a set of reusable UI components that strictly adhere to the "Design System — Components" section of the Design System, supporting the "NeuLedger" glassmorphism aesthetic.

#### Scenario: TransactionRow Display
- **WHEN** displaying a transaction in a list
- **THEN** it MUST show an icon representing the category
- **THEN** it MUST show the transaction title (e.g., "Lunch")
- **THEN** it MUST show the subtitle with category and payment method (e.g., "Food · Cash")
- **THEN** it MUST show the amount in red if expense, green (or default) if income
- **THEN** it MUST show the date/time

#### Scenario: AccountCard Display
- **WHEN** displaying an account summary
- **THEN** it MUST look like a glass card with rounded corners
- **THEN** it MUST show the account icon and name
- **THEN** it MUST show the current balance in a large font
- **THEN** it MUST show the account type (e.g., "Bank")

#### Scenario: InsightCard Display
- **WHEN** displaying an AI insight
- **THEN** it MUST use a glass background
- **THEN** it MUST show a "sparkle" icon
- **THEN** it MUST show a title (e.g., "AI Insight") and the body text

#### Scenario: PrimaryButton Display
- **WHEN** displaying a primary call-to-action button (e.g., in Onboarding)
- **THEN** it MUST use `Color.Design.brandPrimary` as the background color
- **THEN** it MUST use a `Capsule` (pill) shape for the corner radius
- **THEN** it MUST have a height of `56pt` and span the full width of its container
- **THEN** it MUST show the title text in `17pt` Semibold, White color
- **THEN** it MAY optionally show a trailing SF Symbol icon

#### Scenario: Component Previews
- **WHEN** developing any of the components (`TransactionRow`, `AccountCard`, `CategoryChip`, `TagPill`, `BalanceDisplay`, `InsightCard`, `BudgetGauge`, `GlassButton`, `PrimaryButton`, `GlassContainer`, `QuickActionBar`)
- **THEN** each component file MUST include a SwiftUI `#Preview` block
- **THEN** the preview MUST demonstrate the component in its primary state

### Requirement: Glassmorphism Style Adherence

#### Scenario: Visual Style
- **WHEN** rendering any "Glass" component (`GlassButton`, `GlassContainer`, `AccountCard`, etc.)
- **THEN** it MUST use a blur effect (Material or similar) background
- **THEN** it MUST use the specified corner radius from the design system
- **THEN** it MUST use the correct text colors and hierarchy defined in Typography
