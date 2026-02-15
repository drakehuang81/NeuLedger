## ADDED Requirements

### Requirement: DesignTokens SPM Package
The system SHALL provide a local SPM package named `DesignTokens` located at the project root directory (`DesignTokens/`). This package serves as the **Base layer** of the three-tier modular architecture (Base → Infrastructure → Features).

#### Scenario: Package Configuration
- **WHEN** the `DesignTokens/Package.swift` is inspected
- **THEN** it MUST declare:
  - `swift-tools-version: 6.2`
  - Platform: `.iOS(.v26)`
  - A single library product named `DesignTokens`
  - **Zero** external dependencies (no TCA, no third-party packages)
- **AND** the package MUST compile independently when its Xcode Scheme is selected

#### Scenario: Package Structure
- **WHEN** the `DesignTokens/` directory is inspected
- **THEN** it MUST contain:
```
DesignTokens/
├── Package.swift
└── Sources/DesignTokens/
    ├── ColorTokens.swift
    └── FontTokens.swift
```

---

### Requirement: Color Design Tokens
The `DesignTokens` module SHALL define all brand and semantic colors as Pure Code (no Asset Catalog dependency), exposed via `Color.Design` namespace.

#### Scenario: Accessing Brand Colors
- **WHEN** a developer accesses `Color.Design.incomeGreen`
- **THEN** the system SHALL return a `Color` that adapts to Light/Dark mode automatically
- **AND** the Light mode value MUST be `#34C759` (rgb: 0.204, 0.780, 0.349)
- **AND** the Dark mode value MUST be `#30D158` (rgb: 0.188, 0.820, 0.345)

#### Scenario: Complete Brand Color Palette
- **WHEN** the `Color.Design` namespace is inspected
- **THEN** it MUST define the following brand colors:

| Token | Light Mode | Dark Mode | Usage |
|-------|-----------|-----------|-------|
| `incomeGreen` | #34C759 | #30D158 | Income amounts, positive deltas |
| `expenseRed` | #FF3B30 | #FF453A | Expense amounts, negative deltas |
| `warningAmber` | #FF9500 | #FF9F0A | Budget warnings |

#### Scenario: Semantic UI Colors
- **WHEN** the `Color.Design` namespace is inspected
- **THEN** it MUST define the following semantic colors:

| Token | Implementation | Usage |
|-------|---------------|-------|
| `textPrimary` | `.primary` | Main text content |
| `textSecondary` | `.secondary` | Supporting text, subtitles |
| `background` | `Color(.systemBackground)` | Screen backgrounds |
| `groupedBackground` | `Color(.systemGroupedBackground)` | List / Form backgrounds |
| `cardSurface` | `Color(.secondarySystemGroupedBackground)` | Elevated card surfaces |
| `separator` | `Color(.separator)` | Divider lines |

#### Scenario: Light/Dark Mode Adaptation
- **WHEN** the system appearance changes between Light and Dark mode
- **THEN** all `Color.Design` tokens MUST adapt automatically
- **AND** brand colors MUST use `Color(light:dark:)` initializer (iOS 17+)
- **AND** semantic colors MUST wrap system `UIColor` semantic constants

---

### Requirement: Font Design Tokens
The `DesignTokens` module SHALL define all typography tokens via `Font.Design` namespace, using system text styles exclusively (no hardcoded point sizes).

#### Scenario: Accessing Typography Tokens
- **WHEN** a developer accesses `Font.Design.title2`
- **THEN** it SHALL return the equivalent of `Font.title2`
- **AND** it MUST scale with Dynamic Type automatically

#### Scenario: Complete Font Token Set
- **WHEN** the `Font.Design` namespace is inspected
- **THEN** it MUST define the following tokens:

| Token | SwiftUI Font | Usage |
|-------|-------------|-------|
| `largeTitle` | `.largeTitle` | Screen headings |
| `title2` | `.title2` | Section headings |
| `headline` | `.headline` | Card titles, labels |
| `body` | `.body` | General content |
| `callout` | `.callout` | Supporting text |
| `subheadline` | `.subheadline` | List subtitles |
| `caption` | `.caption` | Timestamps, metadata |
| `amount` | `.system(.title, design: .rounded, weight: .bold).monospacedDigit()` | Monetary values |

#### Scenario: Amount Font Special Treatment
- **WHEN** a developer accesses `Font.Design.amount`
- **THEN** it MUST return a monospaced-digit, rounded-design, bold-weight Title-size font
- **AND** it MUST scale with Dynamic Type

---

### Requirement: Access Control
All public APIs in the `DesignTokens` module MUST be explicitly marked `public`.

#### Scenario: Cross-Module Access
- **WHEN** the `Features` module imports `DesignTokens`
- **THEN** all `Color.Design.*` and `Font.Design.*` tokens MUST be accessible
- **AND** no `internal` types or properties SHALL leak into the public API surface

---

### Requirement: Dependency Direction
The `DesignTokens` package MUST NOT depend on any other local or remote package. It is the foundation (Base layer) of the dependency graph.

#### Scenario: Verify Zero Dependencies
- **WHEN** `DesignTokens/Package.swift` is inspected
- **THEN** the `dependencies` array MUST be empty (`[]`)
- **AND** no `import` statements in source files SHALL reference `ComposableArchitecture`, `Features`, or any third-party framework
- **AND** only `import SwiftUI` is permitted
