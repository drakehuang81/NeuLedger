## MODIFIED Requirements

### Requirement: Design System Implementation [ADDED 2026-02-14]
The system SHALL provide Design System capabilities through **SPM packages** instead of a monolithic `NeuLedger/DesignSystem` directory. Design Tokens (colors, fonts) SHALL reside in the `DesignTokens` package (Base layer), and Glass UI components SHALL reside in the `Features` package under `Components/`.

#### Scenario: Using Design Colors [ADDED 2026-02-14]
- **WHEN** a developer accesses `Color.Design.incomeGreen`
- **THEN** it returns the correct color defined in `DesignTokens/Sources/DesignTokens/ColorTokens.swift` via Pure Code, adapting to Light/Dark mode automatically
- **AND** it MUST NOT rely on `Assets.xcassets` Color Sets

#### Scenario: Using Design Fonts [ADDED 2026-02-14]
- **WHEN** a developer accesses `Font.Design.amount`
- **THEN** it returns a monospaced, rounded, bold Title font that scales with Dynamic Type
- **AND** it is defined in `DesignTokens/Sources/DesignTokens/FontTokens.swift`

#### Scenario: Applying Liquid Glass Effect [ADDED 2026-02-14]
- **WHEN** a developer applies `.glassEffect(.regular)` to a View
- **THEN** the view renders with iOS 26 native Liquid Glass treatment
- **AND** the Glass UI components (`GlassCard`, `GlassButton`, `GlassHeader`) are accessible via `import Features`

---

### Requirement: Color System
Prefer **system semantic colors** over hardcoded hex values. Custom brand colors SHALL be defined as **Pure Code** in the `DesignTokens` SPM package using `Color(light:dark:)` initializer. Asset Catalog Color Sets are NOT used for Design Token colors.

#### Scenario: System Colors (Primary Palette)
- **WHEN** styling UI elements
- **THEN** prefer SwiftUI semantic colors:

| Usage | Color | Notes |
|-------|-------|-------|
| Primary actions, tint | `.tint` / `.accentColor` | Set app-wide accent via `AccentColor` in App Target's Asset Catalog |
| Primary text | `.primary` | Adapts to Light/Dark automatically |
| Secondary text | `.secondary` | System gray, adapts automatically |
| Background (screen) | `Color(.systemBackground)` | System white/black |
| Background (grouped) | `Color(.systemGroupedBackground)` | For `List` / `Form` backgrounds |
| Card surface | `Color(.secondarySystemGroupedBackground)` | Elevated cards |
| Separator | `Color(.separator)` | Thin divider lines |

#### Scenario: Brand & Semantic Colors (Pure Code)
- **WHEN** the design system is established
- **THEN** define these custom colors as Pure Code in `DesignTokens/Sources/DesignTokens/ColorTokens.swift`:

| Token | Light Mode | Dark Mode | Usage |
|-------|-----------|-----------|-------|
| `Color.Design.incomeGreen` | #34C759 | #30D158 | Income amounts, positive deltas |
| `Color.Design.expenseRed` | #FF3B30 | #FF453A | Expense amounts, negative deltas |
| `Color.Design.warningAmber` | #FF9500 | #FF9F0A | Budget warnings |

- **AND** `AccentColor` SHALL remain in the App Target's `Assets.xcassets` as it is a system-level tint requiring Asset Catalog for Xcode integration
- **AND** brand colors MUST use `Color(light:dark:)` for automatic Light/Dark adaptation

#### Scenario: Category Colors
- **WHEN** displaying category chips or charts
- **THEN** use a predefined palette of **12+ colors** from iOS system colors (`.blue`, `.purple`, `.orange`, `.pink`, `.mint`, `.teal`, `.cyan`, `.indigo`, `.brown`, `.red`, `.green`, `.yellow`) for chart differentiation.

## ADDED Requirements

### Requirement: GlassButtonStyle Component
The system SHALL provide a `GlassButtonStyle` conforming to SwiftUI's `ButtonStyle` protocol, using iOS 26 native `Glass` and `.glassEffect()` APIs.

#### Scenario: Default Glass Button Style
- **WHEN** a developer applies `.buttonStyle(.glass())` to a Button
- **THEN** the button MUST render with:
  - Horizontal padding of 20pt and vertical padding of 12pt
  - `.glassEffect()` with interactive `Glass` tint in a `Capsule` shape
  - Pressed state opacity of 0.8

#### Scenario: Tinted Glass Button Style
- **WHEN** a developer applies `.buttonStyle(.glass(.blue))` to a Button
- **THEN** the button MUST render with a blue-tinted Glass effect
- **AND** the tint parameter MUST accept any `Glass.Tint` value

#### Scenario: GlassButton Convenience View
- **WHEN** a developer uses `GlassButton(title:action:style:)`
- **THEN** it MUST render a `Button` with the specified `GlassButtonStyle`
- **AND** the default style MUST be `.glass(.clear)`

---

### Requirement: Glass Component Module Location
All Glass UI components (`GlassButton`, `GlassButtonStyle`, `GlassCard`, `GlassHeader`) SHALL reside in the `Features` SPM package under `Sources/Features/Components/`.

#### Scenario: Import Path for Glass Components
- **WHEN** a Feature View needs to use `GlassCard`
- **THEN** it is available directly since it resides in the same `Features` module (no additional `import` needed)
- **AND** the component MUST access Design Tokens via `import DesignTokens` within its source file

#### Scenario: Glass Components Access Control
- **WHEN** Glass components are inspected
- **THEN** all component `struct` declarations, `init` methods, and `body` properties MUST be marked `public`
- **AND** internal implementation details (private properties, helper methods) MUST remain `internal` or `private`

## REMOVED Requirements

### Requirement: Asset Catalog Brand Colors
**Reason**: Brand colors (`incomeGreen`, `expenseRed`, `warningAmber`) are migrated from Asset Catalog Color Sets to Pure Code in the `DesignTokens` SPM package. This enables SPM packages to access design tokens without depending on the App Target's resource bundle.

**Migration**: Replace `Color("incomeGreen")` with `Color.Design.incomeGreen` (defined in `DesignTokens/Sources/DesignTokens/ColorTokens.swift`). The `AccentColor` Color Set remains in the App Target's Asset Catalog.
