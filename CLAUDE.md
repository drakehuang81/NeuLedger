# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Code Navigation

Swift LSP is installed and available via the `LSP` tool. **Always prefer LSP over Grep/Glob for Swift code navigation:**

- Find definitions → `LSP` (hover, go-to-definition) instead of `Grep`
- Find references → `LSP` (find references) instead of `Grep`
- Check type info / signatures → `LSP` (hover) instead of reading whole files
- Rename symbols → `LSP` (rename) instead of manual search-and-replace

Only fall back to `Grep`/`Glob` when LSP cannot help (e.g., searching comments, file-level patterns, or non-Swift files).

## Build & Test

All code lives in the local SPM package at `Features/`. The app target (`NeuLedger.xcodeproj`) simply imports it.

```bash
# Build app
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# Run all tests (NeuLedgerTests target lives in the xcodeproj)
xcodebuild test -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# Run a single test suite
xcodebuild test -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:NeuLedgerTests/DashboardFeatureTests

# Available schemes:
#   NeuLedger (build + tests via NeuLedgerTests/NeuLedgerUITests) — shared in xcodeproj
#   Features / Core / Domain / Common (build only) — shared SPM library schemes
```

> `swift test` does NOT work — iOS 26-only APIs (Liquid Glass, Foundation Models, etc.) cause compile errors on macOS.

## Git Workflow

**All changes go through Pull Requests** — `developer` and `main` are protected (no direct push, no force push, no deletions). Even single-line fixes flow through a `feature/*` / `fix/*` branch + PR.

### Branch naming

| Prefix | Use | Triggers Xcode Cloud PR workflow? |
|---|---|---|
| `feature/<name>` | New features | ✅ Yes |
| `fix/<name>` | Bug fixes | ✅ Yes |
| `PR/<name>` | Misc work that should still run CI | ✅ Yes |
| anything else (`chore/*`, `docs/*`, `experiment/*`...) | Local-only or non-CI work | ❌ No |

### Xcode Cloud trigger model

Three workflows, each triggered by a distinct mechanism — **no `developer` push trigger**:

| Workflow | Trigger | Action |
|---|---|---|
| **PR** | Push to `feature/*`, `fix/*`, `PR/*` | Build + Test (no archive) |
| **TestFlight** | Tag push matching `v*.*.*-beta*` (e.g. `v1.2.0-beta1`) | Archive + upload to TestFlight |
| **Release** | Tag push matching `v*.*.*` or manual trigger from App Store Connect | Archive + App Store submission |

### `[ci skip]` convention

Xcode Cloud natively skips builds when the commit message or PR title contains any of: `[ci skip]`, `[skip ci]`, `[ci-skip]`, `[skip-ci]`, `***NO_CI***`.

**Default: every commit I author gets `[ci skip]` appended to the subject line.** Xcode Cloud is opt-in, not opt-out — the user explicitly triggers CI when they want it by telling me "run CI on this one" / "讓 CI 跑" / similar. Until then, assume CI should not run.

When the user opts in, drop `[ci skip]` from **that specific commit's** subject only; subsequent commits revert to the default-skip behavior unless told again.

**Never** strip `[ci skip]` from a commit someone else authored without asking.

### Release / TestFlight

I do **not** push tags matching `v*.*.*-beta*` or `v*.*.*`, and do **not** manually trigger the Release workflow from App Store Connect. Those are version-cut decisions for the user.

### Misc

- Use `git pull --rebase` (not plain `git pull`) when syncing a PR branch with target.
- Prefer `commit-commands:commit-push-pr` for opening PRs.

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
- **Typography tokens:** All `.font(...)` calls **must** funnel through `Font.Design` (`Common/DesignSystem/Font+extension.swift`). `Font.system(size:...)` / `.font(.system(size:...))` is the file-private hex of typography — it is the only sanctioned location for those calls. Two scales:
  - **Dynamic Type** — `Font.Design.body` / `.caption` / `.headline` / `.callout` / `.amount`. Use for body text, form labels, readable content that should follow the user's text-size preference.
  - **Fixed pixel** — `Font.Design.size{N}{Weight?}{Design?}` (e.g. `size11Medium`, `size13Semibold`, `size14`, `size22SemiboldRounded`, `size10MediumMonospaced`). Use for chrome (tags, pills, badges, metric labels, row meta, navigation strips) and display sizes (hero numbers, headings) where the design specifies an exact pixel size that must not Dynamic-Type-scale.
  - **Gateway rule:** never write `.system(size:...)` outside `Font+extension.swift`. If no existing token fits a new design need, **add one to `Font.Design` first**, then reference it from the call site. When a new use is close to an existing token (off by one weight step, half-pixel rounding, etc.), prefer rounding to the nearest existing token over introducing a single-use new one.
- **Brand colors** (Asset Catalog with Light/Dark variants): `accentColor` (#FF9500 / #FF9F0A), `incomeGreen` (#34C759 / #30D158), `expenseRed` (#FF3B30 / #FF453A), `surfaceInverse`, `textInverse`
- **Liquid Glass:** Use `.glassEffect()` for cards, action bars, and floating elements. `.buttonStyle(.glass)` / `.buttonStyle(.glassProminent)` for buttons. Wrap related glass elements in `GlassEffectContainer`. Use `@Namespace` + `.glassEffectID` for morphing transitions.
- **Reusable components:** `TransactionRow`, `AccountChip`, `TagPill`, `InsightCard`, `BudgetGauge`, `EmptyStateView`, `LoadingView`, `LedgerCutIcon`, `AppIconBadge`, `AvatarBadge`, `GlassContainer`, `GlassCard`, `WarmGradientBackground`, `ColorSwatchPicker`, `BudgetCategoryListPicker`, `IconPickerRow`, `FormSection`, `DetailField`, `PrimaryButton`, `ErrorText`, `SectionFailureView`, `MetricBadge`, `StatPill`, `MiniSparkline`, `PageDots`, `FlowLayout`
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

## Superpowers Workflow

This project uses the **superpowers** plugin. Skills override default Claude behavior, but instructions in this file always take highest priority.

### Skill Trigger Map

| Situation | Skill to invoke |
|-----------|----------------|
| Starting any new feature / creative work | `superpowers:brainstorming` |
| Have a spec, ready to plan implementation | `superpowers:writing-plans` |
| Have a plan, ready to execute | `superpowers:subagent-driven-development` (preferred) or `superpowers:executing-plans` |
| Encountered a bug or test failure | `superpowers:systematic-debugging` |
| Implementing any feature or bugfix | `superpowers:test-driven-development` |
| About to claim work is done | `superpowers:verification-before-completion` |
| Work is complete, ready to ship | `superpowers:finishing-a-development-branch` |
| Need isolated workspace for a feature | `superpowers:using-git-worktrees` |

### Project-Specific Overrides

**Implementation plans** (from `writing-plans` skill) → save to `docs/superpowers/plans/YYYY-MM-DD-<feature-name>.md`

**TDD test commands** (from `test-driven-development` skill) — use xcodebuild, NOT `swift test`:

```bash
# Run all tests
xcodebuild test -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# Run a single suite
xcodebuild test -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:NeuLedgerTests/<SuiteName>
```

Tests use **Swift Testing** (`@Suite`, `@Test`) — not XCTest. TDD cycle applies the same: write failing test → watch it fail → implement minimally → pass.

**Commits** → use `commit-commands:commit` skill.

**PR** → use `commit-commands:commit-push-pr` skill.

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
- **All `Color` values must go through `Color.Design`** (`Common/DesignSystem/Color+extension.swift`). The hex-to-`Color` initializer is `fileprivate` to that file — direct `Color(hex: ...)` calls do not compile. Two sanctioned paths:
  - **Design constants** (brand, accent, splash, ledger-cut, settings-tile icons, warm-gradient backdrop, etc.) → add a named static member to `Color.Design`, then reference it via `Color.Design.tokenName`
  - **Runtime hex strings from domain models** (`SDAccount.color`, `SDCategory.color`, `SDTag.color`) → use `Color.Design.fromHex(_:)`
  - No exceptions. Do not introduce a second hex helper (no `init(warmHex:)`-style duplicates), and do not hardcode `#000000` / `#FFFFFF` literals in views
- Floating Split TabBar requires bottom padding in all scrollable content so no content hides behind it
- All user-facing strings must use `String(localized:)` or `LocalizedStringKey` — never hardcode raw strings in views or reducers
