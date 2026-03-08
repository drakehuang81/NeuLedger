# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Test

All code lives in the local SPM package at `Features/`. The app target (`NeuLedger.xcodeproj`) simply imports it.

```bash
# Build app
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 16'

# Run tests for a specific module (schemes: Domain, Core, Common, Features, NeuLedger)
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 16'

# Run a single test suite
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:FeaturesTests/DashboardFeatureTests
```

> `swift test` does NOT work — iOS 26-only APIs (Liquid Glass, Foundation Models, etc.) cause compile errors on macOS.

## Architecture

The project uses **Clean Architecture + TCA (v1.23.1)** with a local SPM package split into four targets:

```
Features/Sources/
├── Domain/      # Zero persistence deps. Pure Swift entities + @DependencyClient interfaces.
├── Core/        # SwiftData models (SD-prefixed), live client implementations, mappers.
├── Common/      # Design system, extensions, shared SwiftUI components. No dependencies.
└── Features/    # TCA Reducers + SwiftUI Views. Depends on all three above.
```

**Dependency direction:** `Features → Core → Domain`. Feature modules never import SwiftData directly.

### Domain Layer

**Entities** (plain `struct` values in `Domain/Entities/`):
- `Transaction` — `id`, `amount`, `date`, `note`, `categoryId`, `accountId`, `toAccountId` (transfers only), `type`, `tags`, `aiSuggested`, `createdAt`, `updatedAt`
- `Account` — `id`, `name`, `type`, `icon`, `color`, `sortOrder`, `isArchived`, `createdAt`
- `Category` — `id`, `name`, `icon`, `color`, `type`, `sortOrder`, `isDefault`
- `Tag` — `id`, `name`, `color`
- `Budget` — `id`, `name`, `amount`, `categoryId`, `period`, `startDate`, `isActive`
- `TransactionFilter` — composable filter struct (`categoryIds`, `accountIds`, `tagIds`, `types`, `dateRange`, `searchText`) — all `nil` means "no filter applied"

**Key enums:** `TransactionType` (`.expense`, `.income`, `.transfer`), `AccountType` (`.cash`, `.bank`, `.creditCard`, `.eWallet`), `BudgetPeriod` (`.weekly`, `.monthly`, `.yearly`), `Currency` (`.TWD` only — symbol "NT$", zero decimal places)

**AI types:** `ExtractedTransaction`, `CategorySuggestions`, `SpendingSummary`

**Client interfaces** use `@DependencyClient` macro and declare `testValue = Self()` (unimplemented stubs). `DependencyValues` extension registers each client:

| Key path | Key methods |
|----------|-------------|
| `\.transactionClient` | `fetchRecent`, `fetchAll`, `fetch(TransactionFilter)`, `search(String)`, `add`, `update`, `delete` |
| `\.accountClient` | `fetchAll`, `fetchActive`, `add`, `update`, `archive`, `delete`, `computeBalance` |
| `\.categoryClient` | `fetchAll`, `fetch(TransactionType)`, `add`, `update`, `delete` |
| `\.budgetClient` | `fetchAll`, `fetchActive`, `add`, `update`, `delete` |
| `\.tagClient` | `fetchAll`, `add`, `update`, `delete` |
| `\.aiServiceClient` | `extractTransaction(String)`, `suggestCategories(String,[String])`, `generateInsight(SpendingSummary)`, `isAvailable()` |

### Core Layer

- SwiftData `@Model` classes are prefixed `SD` (e.g., `SDTransaction`, `SDAccount`)
- All five models (`SDTransaction`, `SDAccount`, `SDCategory`, `SDBudget`, `SDTag`) must be in the `Schema` array of `DatabaseClient.liveValue` and `testValue`
- Domain enums are stored as raw `String` values; mappers convert via `init(rawValue:)`
- `SDTransaction` has a `@Relationship` to `[SDTag]` (many-to-many); `SDTag` has the inverse `@Relationship` back
- All models conform to `DomainConvertible` (in their `+Mapping.swift` files): `toDomain()` and `static func from(_:context:)`
- `DatabaseClient` holds the shared `ModelContainer`. Live client implementations inject it via `@Dependency(\.databaseClient)` and use helpers from `SwiftDataHelpers.swift`:
  - `databaseClient.fetch(_:)` — fetch + map to domain in one call
  - `databaseClient.add(_:as:)` — insert + save
  - `databaseClient.update(matching:mutation:)` — find (fetchLimit=1) + mutate closure + save
  - `databaseClient.deleteFirst(matching:validation:)` — find (fetchLimit=1) + optional guard + delete + save
- `CoreError.notFound` / `.operationDenied` are the only error types thrown from the Core layer
- Default data seeding (via `seedIfNeeded(in:)` in `DatabaseClient.swift`) populates default categories and the default "Cash" account on first launch (only when `SDCategory` count == 0)
- All SwiftData operations run on a `@ModelActor`-isolated context for thread safety

### Features Layer

**App routing:** `AppFeature` defines `enum Destination { case onboarding(OnboardingFeature.State), case main }`. On launch it reads `userSettingsClient.bool(.hasCompletedOnboarding)` to set the initial destination. `AppView` renders `OnboardingView` or `MainTabView` based on destination.

**Main tabs:** `MainTabFeature` composes four tabs — Dashboard, Transactions, Analysis, Settings — with a custom **Split Capsule TabBar** floating above the bottom safe area (left capsule: tab navigation; right capsule: global context action such as search or add).

**Onboarding flow:** `OnboardingFeature` — 3 steps: Welcome → Account Setup (creates first account) → Ready. Skippable at any step (defaults used). Sends `.delegate(.onboardingCompleted)` when done; `AppFeature` receives it and switches `destination` to `.main`.

**TCA patterns in use:**
- `@Reducer` macro with `@ObservableState` on `State` and `@Dependency` for injected clients
- **Tree-based navigation** for modals/sheets: `@Presents var child: ChildFeature.State?` + `PresentationAction`
- **Stack-based navigation** for push flows: `StackState` / `StackAction`
- **Delegate pattern** for child → parent communication: a `delegate(Delegate)` action case with `@CasePathable enum Delegate`
- Cancel IDs declared as a private `enum CancelID` inside each `@Reducer`

### Design System (Common Layer)

- **Fonts:** `--font-display` → Bricolage Grotesque (screen headings), `--font-body` → DM Sans (general content), `--font-mono` → DM Mono (monetary amounts, always `.monospacedDigit()`)
- **Brand colors** (Asset Catalog with Light/Dark variants): `accentColor` (#FF9500 / #FF9F0A), `incomeGreen` (#34C759 / #30D158), `expenseRed` (#FF3B30 / #FF453A), `surfaceInverse`, `textInverse`
- **Liquid Glass:** Use `.glassEffect()` for cards, action bars, and floating elements. `.buttonStyle(.glass)` / `.buttonStyle(.glassProminent)` for buttons. Wrap related glass elements in `GlassEffectContainer`. Use `@Namespace` + `.glassEffectID` for morphing transitions.
- **Reusable components:** `TransactionRow`, `AccountCard`, `CategoryChip`, `TagPill`, `BalanceDisplay`, `InsightCard`, `BudgetGauge`, `EmptyStateView`
- **Icons:** SF Symbols only. Do not mix icon sets. `.symbolRenderingMode(.hierarchical)` for multi-layered icons. No emojis as functional UI icons.

### AI Integration

- Framework: Apple **Foundation Models** (`import FoundationModels`) — fully on-device, no network calls
- Availability: check `SystemLanguageModel.default.isAvailable` at runtime; if `false`, AI features gracefully hide (manual input still fully functional)
- Structured output: `@Generable` structs + `LanguageModelSession` for extraction and category suggestions
- Text generation: `LanguageModelSession` for spending insights in Traditional Chinese
- All AI access goes through `\.aiServiceClient` dependency; current `.liveValue` returns empty placeholder results

## Testing

Tests use **Swift Testing** (`@Suite`, `@Test`), not XCTest.

Feature tests use TCA `TestStore` with dependency overrides:

```swift
let store = await TestStore(initialState: DashboardFeature.State()) {
    DashboardFeature()
} withDependencies: {
    $0.transactionClient.fetchRecent = { Self.sampleTransactions }
}
await store.send(.task) { $0.isLoading = true }
await store.receive(\.transactionsUpdated) { ... }
```

Core/persistence tests use `DatabaseClient.testValue` (in-memory SwiftData container).

Domain tests verify: entity protocol conformance (Equatable, Hashable, Codable round-trip), enum `allCases` completeness and raw values, `TransactionFilter` equality, and `@DependencyClient` `testValue` accessibility via `DependencyValues` key paths.

## Spec-Driven Workflow

Feature development follows specs in `openspec/specs/` organised in three layers:

1. **Core & Tech** (`xxxxx.md`) — architecture, data models, persistence, design system, AI integration
2. **Feature specs** (`feature-xxxxx.md`) — business logic, client interfaces, validation rules
3. **Screen specs** (`screen-xxxxx.md`) — UI structure, interactions, layout

Agent workflows use the `opsx` skill prefix (e.g., `/opsx:new`, `/opsx:apply`, `/opsx:verify`, `/opsx:archive`).

## Key Constraints

- **iOS 26.0 minimum** — no `#available` checks needed; use Liquid Glass, Foundation Models, Swift Charts directly
- Features must never import `SwiftData` directly — always go through a `Client`
- All monetary amounts are **TWD only**, displayed as integers with "NT$" prefix — no decimal places, no `currency` field on any entity
- Account balances are **computed on-the-fly** from transactions — never stored as a persistent field
- New clients: interface in `Domain/Clients/`, live implementation in `Core/Clients/` conforming to `DependencyKey`
- New SwiftData models must be added to the `Schema` array in both `DatabaseClient.liveValue` and `testValue`
- Default categories (`isDefault == true`) must not be deletable
- Accounts with associated transactions can only be **archived**, not permanently deleted
- Tag deletion must automatically disassociate the tag from all linked transactions
- Validation errors use **inline** messages — never `Alert` for form validation failures
- Do not hardcode `#000000` / `#FFFFFF` in views — use semantic colors or Asset Catalog color sets with Dark Mode variants
- Floating Split TabBar requires bottom padding in all scrollable content so no content hides behind it
