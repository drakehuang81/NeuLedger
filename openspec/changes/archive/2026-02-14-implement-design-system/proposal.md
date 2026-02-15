
# Proposal: Implement NeuLedger Design System

**Status**: Proposed
**Type**: Implementation

## Goal

Implement the core NeuLedger Design System as defined in the Architecture Blueprint and Design System specifications. This establishes the foundational UI layer for the application, ensuring consistency, accessibility, and modern aesthetics (Liquid Glass) from the start.

## Context

We have defined the high-level design system requirements in `openspec/specs/design-system.md`, including color palettes, typography, and component behaviors. Now we need to translate these requirements into reusable SwiftUI code.

This implementation focuses on:
1.  **Color System**: Semantic colors and asset catalog setup.
2.  **Typography**: Dynamic Type compliant font styles.
3.  **Liquid Glass**: Reusable view modifiers for glassmorphism.
4.  **Core Components**: Buttons, cards, and basic layout containers.

## What Changes

We will introduce a new `DesignSystem` module (folder) within the app structure containing:
-   `Color+Design.swift`: Extensions for `Color` to support semantic tokens.
-   `Font+Design.swift`: Extensions for `Font` to support the typography system.
-   `LiquidGlass.swift`: View modifiers for applying glass effects.
-   `Components/`: Directory for reusable UI components (e.g., `GlassButton`, `GlassCard`).

No changes to external dependencies or major architectural boundaries are expected.

## Capabilities

### New Capabilities
<!-- Capabilities being introduced. -->
- `ui-components`: Implementation of specific reusable UI components (Buttons, Cards, Chips).

### Modified Capabilities
<!-- Existing capabilities whose REQUIREMENTS are changing or being refined. -->
- `design-system`: Refining implementation details and usage guidelines for the design system based on actual SwiftUI implementation constraints.

## Impact

-   **Codebase**: Adds `NeuLedger/DesignSystem` directory.
-   **Developers**: All future UI development must use these tokens and components instead of raw SwiftUI values.
