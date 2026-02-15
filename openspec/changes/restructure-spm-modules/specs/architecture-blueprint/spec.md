## MODIFIED Requirements

### Requirement: Clean Architecture Organization
The project follows Clean Architecture with clear separation between Domain, Data, and Presentation layers. The codebase SHALL be organized as **SPM local packages** following a three-tier modular architecture (Base → Infrastructure → Features), with the main App Target serving as the Composer.

#### Scenario: Verify Project Structure
- **WHEN** the project root is inspected
- **THEN** the following top-level structure MUST exist:

```
NeuLedger/                              (project root)
├── DesignTokens/                       (Base layer — local SPM package)
│   ├── Package.swift
│   └── Sources/DesignTokens/
│       ├── ColorTokens.swift
│       └── FontTokens.swift
├── Features/                           (Features layer — local SPM package)
│   ├── Package.swift
│   ├── Sources/Features/
│   │   ├── App.swift                   # @main entry point
│   │   └── Components/
│   │       ├── GlassButton.swift
│   │       ├── GlassButtonStyle.swift
│   │       ├── GlassCard.swift
│   │       └── GlassHeader.swift
│   └── Tests/FeaturesTests/
├── NeuLedger/                          (App Target — Composer)
│   ├── NeuLedgerApp.swift              # Empty shell (no @main)
│   ├── Assets.xcassets/                # AppIcon, AccentColor only
│   ├── Info.plist
│   └── NeuLedger.entitlements
├── NeuLedger.xcodeproj/
├── NeuLedgerTests/
└── NeuLedgerUITests/
```

#### Scenario: SPM Dependency Graph
- **WHEN** the package dependency graph is inspected
- **THEN** it MUST follow strict unidirectional dependencies:
  - `DesignTokens`: zero dependencies (Base layer)
  - `Features`: depends on `DesignTokens` (via local path `../DesignTokens`) and `swift-composable-architecture`
  - App Target (`NeuLedger`): depends on `Features` and `DesignTokens` (via Xcode packageProductDependency)
- **AND** circular dependencies MUST NOT exist
- **AND** Base layer MUST NOT depend on Infrastructure or Features
- **AND** Features layer MUST NOT depend on the App Target

#### Scenario: App Target as Composer
- **WHEN** the main App Target (`NeuLedger`) is inspected
- **THEN** it SHALL serve exclusively as the **Composer** role:
  - It MUST NOT contain business logic, feature views, or design system components
  - It MUST import `Features` and `DesignTokens` packages
  - It SHALL contain only: empty `NeuLedgerApp.swift`, `Assets.xcassets` (AppIcon, AccentColor), `Info.plist`, and `NeuLedger.entitlements`
- **AND** the `@main` entry point MUST reside in the `Features` package (`Features/Sources/Features/App.swift`)

#### Scenario: Independent Package Compilation
- **WHEN** a developer selects the `DesignTokens` Xcode Scheme
- **THEN** the package MUST compile independently without building `Features` or the App Target
- **AND** when a developer selects the `Features` Xcode Scheme
- **THEN** the package MUST compile with only `DesignTokens` and `swift-composable-architecture` as dependencies

## ADDED Requirements

### Requirement: Xcode Project Clean State
The Xcode `project.pbxproj` MUST NOT contain references to non-existent packages or targets.

#### Scenario: No Ghost Package References
- **WHEN** `project.pbxproj` is inspected
- **THEN** it MUST NOT contain any reference to `NeuLedgerUI` (neither in `PBXBuildFile`, `PBXFrameworksBuildPhase`, `XCSwiftPackageProductDependency`, nor `packageProductDependencies`)
- **AND** every `XCSwiftPackageProductDependency` entry MUST correspond to an existing, resolvable package

#### Scenario: Valid Package Dependencies
- **WHEN** the App Target's `packageProductDependencies` are inspected
- **THEN** it MUST list exactly: `Features` and `DesignTokens`
- **AND** both MUST resolve to local SPM packages in the project root

---

### Requirement: Features Package Internal Structure
The `Features` package SHALL host both business feature modules and reusable UI components (Glass components) in a structured directory layout.

#### Scenario: Components Directory
- **WHEN** `Features/Sources/Features/Components/` is inspected
- **THEN** it MUST contain the design system UI components:
  - `GlassButton.swift`
  - `GlassButtonStyle.swift`
  - `GlassCard.swift`
  - `GlassHeader.swift`
- **AND** all component types and initializers MUST be marked `public`
- **AND** all components MUST import `DesignTokens` to access `Color.Design.*` and `Font.Design.*` tokens
