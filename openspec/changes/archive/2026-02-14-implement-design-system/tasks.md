
# Tasks: Design System Implementation

## 1. Setup

- [x] 1.1 Create `NeuLedger/DesignSystem` directory structure
- [x] 1.2 Create `NeuLedger/DesignSystem/DesignSystem.swift` as an entry point/namespace if needed

## 2. Color System

- [x] 2.1 Add semantic color sets (incomeGreen, expenseRed, warningAmber, accentColor) to `Assets.xcassets`
- [x] 2.2 Create `DesignSystem/Tokens/Color+Design.swift` with `Color` extensions

## 3. Typography

- [x] 3.1 Create `DesignSystem/Tokens/Font+Design.swift` with `Font` extensions for semantic text styles (e.g., amount, largeTitle, body)

## 4. Liquid Glass Effect

- [x] 4.1 Create `DesignSystem/Effects/LiquidGlass.swift` implementing the `.glassEffect()` view modifier and extension for `glassEffect`

## 5. Core Components

- [x] 5.1 Implement `DesignSystem/Components/GlassButton.swift` (ButtonStyles)
- [x] 5.2 Implement `DesignSystem/Components/GlassCard.swift` (Generic card container)
- [x] 5.3 Implement `DesignSystem/Components/GlassHeader.swift` (For section headers if needed)

## 6. Integration & Verification

- [x] 6.1 Create a `DesignSystemPreview.swift` file (internal only) to showcase all tokens and components in a single Preview
- [x] 6.2 Verify Dark Mode support in Previews
