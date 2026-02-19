## Context

We are implementing a comprehensive set of UI components based on the "Design System — Components" section of our Pencil designs. The goal is to standardize the visual language of the application using glassmorphism, rounded corners, and consistent typography/colors. Currently, only basic glass components exist (`GlassButton`, `GlassCard`, `GlassHeader`), but we need a complete library covering transaction lists, account summaries, insights, and actions.

## Goals / Non-Goals

**Goals:**
- Implement 10 key UI components defined in the design system:
  1. `TransactionRow`
  2. `AccountCard`
  3. `CategoryChip`
  4. `TagPill`
  5. `BalanceDisplay`
  6. `InsightCard`
  7. `BudgetGauge`
  8. `GlassButton` (Update existing or new)
  9. `GlassContainer` (Or standardize existing `GlassCard`)
  10. `QuickActionBar`
- Ensure all components support SwiftUI Previews using the `#Preview` macro for rapid iteration.
- Adhere strictly to the design specs for colors, fonts, spacing, and corner radii.
- Support both Light and Dark modes (implicitly via semantic colors if defined).

**Non-Goals:**
- Integrating these components into full feature screens (e.g., Dashboard, Transaction List) in this change. This change focuses solely on the component library.
- Creating the core Design System foundations (Colors, Typography) if they don't exist (assuming basic tokens are available or will be defined locally if needed).

## Decisions

- **Framework**: Use **SwiftUI** for all components.
- **Location**: All components will be placed in `Features/Sources/Features/Components/`.
- **Existing Components**: 
  - `GlassButton.swift`: Will be updated to match the new `GlassButton` spec (`id: Addqf`).
  - `GlassCard.swift`: Will be reviewed. If it matches `GlassContainer` (`id: ynp50`), we might rename it or alias it, but likely we'll implement `GlassContainer` as the generic base.
- **Styling**:
  - Use `Material` (ultraThinMaterial, etc.) for glass effects where appropriate, or custom blur views if specific radius control is needed (design mentions "background_blur" with specific radii, e.g., 20, 24). SwiftUI's standard materials often suffice, but we'll aim for closest match.
  - Colors/Fonts: We will use hardcoded values or local constants if a centralized `DesignSystem` module is missing, but prefer semantic names if available (e.g., `Color.glassSurface`).
- **Preview Strategy**: Each component file must contain a `#Preview` block demonstrating representative states (e.g., different variants, content lengths).

## Risks / Trade-offs

- **Blur Performance**: Heavy use of glassmorphism (blurs) can affect scrolling performance on older devices. We will use system standard materials where possible to benefit from OS optimizations.
- **Complexity**: `TransactionRow` has complex content layout. Ensuring it handles dynamic type sizes (Accessibility) might require careful layout planning, though initial implementation will prioritize visual fidelity to design.
