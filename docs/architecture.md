# NeuLedger Architecture Spec

This document is the **source of truth** for layering, naming, and dependency
rules. New code and refactors must conform to this spec; deviations need an
explicit note in code review.

Status: **target architecture** — current code is partly here, partly not.
See [§9 Migration](#9-migration) for the gap.

---

## 1. Layers

```
┌─────────────────────────────────────────────────────────────┐
│ Presentation       Views + Reducers (TCA Features)          │
│                    ↓ only inward                            │
├─────────────────────────────────────────────────────────────┤
│ Application        UseCases — one per bounded context       │
│                    ↓                                        │
├─────────────────────────────────────────────────────────────┤
│ Domain             Entities, ValueObjects, Policies         │
│                    + Repository / Adapter / UseCase         │
│                    interfaces. Zero external imports.       │
├─────────────────────────────────────────────────────────────┤
│ Infrastructure     Repository impl (SwiftData)              │
│                    Adapter impl (UN, UserDefaults,          │
│                    AppGroup, Foundation Models, CloudKit)   │
└─────────────────────────────────────────────────────────────┘
```

Dependency direction: **outer → inner, never reversed.** Inner layers know
nothing about outer ones.

---

## 2. Naming

| Concept | Type Suffix | DI Key Path |
|---|---|---|
| View | `XxxView` | — |
| Reducer | `XxxFeature` | — |
| UseCase | `XxxUseCase` | verb-first, no suffix: `\.ledger`, `\.cloudSync` |
| Repository | `XxxRepository` | `\.xxxRepository` |
| Adapter | `XxxAdapter` | `\.xxxAdapter` |
| Entity | `Xxx` | — |
| Value Object | `Xxx` (descriptive) | — |
| SwiftData Model | `SDXxx` | — |
| Domain Policy | `XxxPolicy` (enum w/ static funcs) | — |

### Why UseCase keypath is verb-first

```swift
@Dependency(\.ledger) var ledger
try await ledger.record(tx)       // reads like an action
```

vs.

```swift
@Dependency(\.ledgerUseCase) var ledgerUseCase
try await ledgerUseCase.record(tx)  // reads like Java enterprise
```

### Repository / Adapter keep their suffix in keypath

To avoid collisions with state field names like `accounts: [Account]` or
`notifications: [Notification]`.

---

## 3. Dependency Rules (Strict)

| Layer | May depend on | May NOT depend on |
|---|---|---|
| **Feature** | UseCase (always) | Repository, Adapter, Database, system APIs (except in `View` body for layout) |
| **UseCase** | Repository, Adapter, other UseCase, Policy, Domain types | Reducer, View, SwiftData, UIKit |
| **Repository** | DatabaseClient, Domain types | Other Repository (rare exceptions for joins — comment why), any Adapter, any UseCase |
| **Adapter** | System APIs, Domain types | Other Adapter, Repository, UseCase |
| **Policy** | Pure Swift only (Foundation OK) | Anything async / throws IO |

**Rationale for strict Feature → UseCase only:** every screen-driven mutation
or composed query is funneled through a UseCase. Future cross-cutting changes
(audit log, telemetry, optimistic UI) only need to touch UseCases, not 15
Reducers.

### One concession

Pure system-API calls that only affect the running app (e.g., open URL,
read-then-display-only) may stay inline in `View` if a UseCase wrapper would
be pure overhead. Example: `UIApplication.shared.open(...)` for a deep link.
But anything that **writes to user data or stored state must go through a
UseCase**.

---

## 4. Repository / Adapter Distinction

> **The data's schema is yours = Repository. Someone else's schema = Adapter.**

| Type | Repository | Adapter |
|---|---|---|
| What it wraps | Persistence of *your* aggregate | External system (Apple's or third-party) |
| Returns | Domain entities (`Transaction`, `Account`, ...) | Domain types translated from system response |
| Examples | `TransactionRepository`, `AccountRepository` | `NotificationAdapter`, `UserSettingsAdapter`, `WidgetSyncAdapter`, `CloudKitSyncAdapter`, `AIAdapter` |
| Implementation | `Core/Repositories/` SwiftData | `Core/Adapters/` system frameworks |

---

## 5. UseCase Catalog (12)

Grouped by **bounded context**, not per-aggregate. Each UseCase is a struct
of `@Sendable` closures, registered as a TCA dependency.

### 🧾 Ledger Context (3)

**`LedgerUseCase`** — Transaction CRUD with enrichment
- `record(_ tx: Transaction) async throws -> Void`
- `update(_ tx: Transaction) async throws -> Void`
- `delete(_ id: Transaction.ID) async throws -> Void`
- `fetch(_ id: Transaction.ID) async throws -> Transaction?`
- `listRecent(limit: Int) async throws -> [EnrichedTransaction]`
- `listAll(filter: TransactionFilter) async throws -> [EnrichedTransaction]`
- `search(query: String) async throws -> [EnrichedTransaction]`

**`AccountUseCase`**
- `create(_ account: Account) async throws -> Void`
- `update(_ account: Account) async throws -> Void`
- `archive(_ id: Account.ID) async throws -> Void`
- `unarchive(_ id: Account.ID) async throws -> Void`
- `delete(_ id: Account.ID) async throws -> Void`
- `listAll() async throws -> [Account]`
- `listActive() async throws -> [Account]`
- `balances() async throws -> [Account.ID: Decimal]`

**`MetadataUseCase`** — Category + Tag combined
- `listCategories(type: TransactionType?) async throws -> [Category]`
- `createCategory(_:)` / `updateCategory(_:)` / `deleteCategory(_:)`
- `listTags() async throws -> [Tag]`
- `createTag(_:)` / `updateTag(_:)` / `deleteTag(_:)`

### 💰 Planning Context (2)

**`BudgetUseCase`**
- `listActive() async throws -> [Budget]`
- `create(_:)` / `update(_:)` / `delete(_:)`
- `currentStatus(of: Budget) async throws -> BudgetStatus`
- `evaluateAfterTransaction(_ tx: Transaction) async -> Void`
  > Called internally by `LedgerUseCase.record/update`. Wraps the
  > BudgetWarningPolicy + NotificationAdapter call chain.

**`RecurringUseCase`**
- `listActive() async throws -> [RecurringTransaction]`
- `create(_:)` / `update(_:)` / `delete(_:)`
- `tick() async throws -> Void`
  > Scheduler entry point — creates due transactions via
  > `LedgerUseCase.record`.

### 📊 Insights Context (1)

**`AnalyticsUseCase`** — all read-only computed views
- `todayStats(referenceDate: Date) async throws -> SpendingStats`
- `weeklySparkline(accountId: Account.ID?) async throws -> [Decimal]`
- `dailyBars(range: DateInterval) async throws -> [DailyAmount]`
- `categoryProportions(range: DateInterval) async throws -> [CategoryProportion]`
- `budgetGauges() async throws -> [BudgetGaugeMetric]`
- `generateAIInsight(summary: SpendingSummary) async throws -> String`
  > AI text generation lives here because it's a *summary of existing data*,
  > not a write action.

### 🤖 Intelligence Context (1)

**`AIUseCase`** — active AI that *creates* data
- `extractFromText(_:) async throws -> ExtractedTransaction`
- `extractFromVoice(_:) async throws -> ExtractedTransaction`
- `suggestCategories(text: String, existing: [String]) async throws -> CategorySuggestions`
- `isAvailable() -> Bool`

### 🏷️ Carrier Context (1)

**`CarrierUseCase`** — Taiwan invoice carrier + widget
- `listAll() async throws -> [Carrier]`
- `create(_:)` / `update(_:)` / `delete(_:)`
- `setActiveForWidget(_ id: Carrier.ID) async -> Void`
- `activeForWidget() -> Carrier.ID?`

### ☁️ Sync Context (1)

**`CloudSyncUseCase`**
- `isAvailable() -> Bool`
- `isEnabled() -> Bool`
- `lastSyncedAt() -> Date?`
- `enable() -> AsyncThrowingStream<Double, Error>`
- `requestNow() async throws -> Void`

### 🛠️ App Environment Context (1)

**`AppEnvironmentUseCase`** — Preference + Notification + System wrappers

Preferences:
- `accessoryMode()` / `setAccessoryMode(_:)`
- `reminderTime()` / `setReminderTime(_:)`
- `budgetWarningEnabled()` / `setBudgetWarningEnabled(_:)`
- `budgetWarningThreshold()` / `setBudgetWarningThreshold(_:)`
- `defaultAccountId()` / `setDefaultAccountId(_:)`
- `hasCompletedOnboarding()` / `markOnboardingComplete()`

Notification:
- `requestNotificationPermission() async -> Bool`
- `scheduleDailyReminder() async -> Void`
- `cancelDailyReminder() async -> Void`

System:
- `openAppSettings() -> Void`

### 🚪 Misc (2)

**`OnboardingUseCase`** — single-shot onboarding flow
- `complete(firstAccount: Account) async throws -> Void`
  > Internally combines `AccountUseCase.create` + `AppEnvironmentUseCase.markOnboardingComplete`.

**`ExportUseCase`**
- `exportTransactionsCSV() async throws -> URL`

---

## 6. Repository Catalog (7)

All Repositories depend **only** on `DatabaseClient`. They return Domain
entities. They never call other Repositories (with one rare exception for
joins, which must be commented).

| Repository | Aggregate |
|---|---|
| `TransactionRepository` | Transaction |
| `AccountRepository` | Account |
| `CategoryRepository` | Category |
| `BudgetRepository` | Budget |
| `TagRepository` | Tag (+ many-to-many disassoc on delete) |
| `CarrierRepository` | Carrier |
| `RecurringTransactionRepository` | RecurringTransaction |

---

## 7. Adapter Catalog (5)

| Adapter | Wraps |
|---|---|
| `UserSettingsAdapter` | `UserDefaults.standard` |
| `NotificationAdapter` | `UNUserNotificationCenter` + per-budget warning state in UserDefaults |
| `WidgetSyncAdapter` | App Group `UserDefaults(suiteName:)` + `WidgetCenter.reloadAllTimelines()` |
| `AIAdapter` | Foundation Models (`SystemLanguageModel` / `LanguageModelSession`) |
| `CloudKitSyncAdapter` | `NSPersistentCloudKitContainer` lifecycle + `lastSyncedAt` |

`DatabaseClient` is **infrastructure but not a typical Adapter** — it
exposes `ModelContainer` directly to Repositories. It is the only thing
Repositories may touch from the infra layer.

---

## 8. File / Folder Layout

```
Features/Sources/
├── Domain/                            # Pure. No external imports.
│   ├── Entities/                      # Transaction, Account, ...
│   ├── ValueObjects/                  # TransactionFilter, EnrichedTransaction
│   ├── Policies/                      # AccountDeletionPolicy, BudgetWarningPolicy
│   ├── Repositories/                  # TransactionRepository.swift (interface)
│   ├── Adapters/                      # NotificationAdapter.swift (interface)
│   └── UseCases/                      # LedgerUseCase.swift (interface)
│
├── Core/                              # Infrastructure implementations
│   ├── Persistence/                   # DatabaseClient
│   ├── Repositories/                  # *Repository+Live.swift (SwiftData)
│   └── Adapters/                      # *Adapter+Live.swift (system APIs)
│
├── Application/                       # UseCase implementations
│   ├── Ledger/
│   │   └── LedgerUseCase+Live.swift
│   ├── Account/
│   │   └── AccountUseCase+Live.swift
│   ├── Metadata/
│   ├── Budget/
│   ├── Recurring/
│   ├── Analytics/
│   ├── AI/
│   ├── Carrier/
│   ├── CloudSync/
│   ├── AppEnvironment/
│   ├── Onboarding/
│   └── Export/
│
├── Common/                            # Design system, shared SwiftUI components
│
└── Features/                          # Presentation (TCA Reducers + Views)
    └── (one folder per screen)
```

---

## 9. Migration

Current state vs target:

| Current | Target |
|---|---|
| `Core/Clients/TransactionClient+Live` (Repository + UseCase mix) | Split → `Core/Repositories/TransactionRepository+Live` (pure) + `Application/Ledger/LedgerUseCase+Live` (orchestration) |
| `Core/Clients/AIServiceClient+Live` (already a UseCase but mis-named) | Rename → `Application/AI/AIUseCase+Live` |
| `Core/Clients/SyncClient+Live` | Rename → `Application/CloudSync/CloudSyncUseCase+Live` |
| `Core/Clients/NotificationClient+Live` | Rename → `Core/Adapters/NotificationAdapter+Live` |
| `Core/Clients/WidgetSyncClient+Live` | Rename → `Core/Adapters/WidgetSyncAdapter+Live` |
| `Core/Clients/UserSettingsClient+Live` | Rename → `Core/Adapters/UserSettingsAdapter+Live` |
| `Domain/Clients/*Client.swift` | Move + split → `Domain/Repositories/`, `Domain/Adapters/`, `Domain/UseCases/` |
| Features directly inject Repository / Adapter | Refactor to inject UseCase only |

This is a multi-PR refactor. Suggested ordering:

1. **Rename only** (no behavior change): Adapters and AIService/Sync renames.
   Low risk, makes the rest readable.
2. **Extract Ledger UseCase**: pull `checkBudgetWarnings` out of
   `TransactionRepository`, create `LedgerUseCase` + `BudgetUseCase`. Update
   Features that record transactions to call `LedgerUseCase.record`.
3. **Introduce remaining UseCases incrementally**, one bounded context per PR.
4. **Folder restructure** (Domain split, new Application folder) — best done
   in the same PR as introducing the new UseCase implementations.

Until migration is complete, the codebase will have both `*Client` and
`*UseCase` / `*Repository` / `*Adapter` names. That's expected; the spec is
the target, the code follows.

---

## 10. Anti-Patterns

| Smell | What to do instead |
|---|---|
| Reducer imports `SwiftData` or `UserDefaults` | Use a UseCase / Adapter |
| Repository fetches + then computes business logic | Move the logic to a Policy or UseCase |
| Two Repositories know about each other | One UseCase composes both |
| UseCase named after a screen (`DashboardUseCase`) | Rename around a domain concept |
| Adapter calls another Adapter | Compose at the UseCase layer instead |
| Policy is `async throws` | It's a UseCase, not a Policy |
| 30-method UseCase | Split by sub-context; don't let it grow past ~15 methods |
| New `XxxClient` file | Decide: Repository, Adapter, or UseCase — never the ambiguous "Client" |

---

## 11. Testability

Each layer has a clear test surface:

- **Policy**: pure function tests, fastest, no setup
- **Adapter** (Live): integration tests against real system APIs (sparingly)
- **Repository** (Live): in-memory `DatabaseClient.testValue` + Swift Testing
- **UseCase**: TCA `TestStore` with Repository/Adapter overridden via
  `withDependencies` — fast, deterministic
- **Feature**: `TestStore` with **UseCase** overridden via `withDependencies` —
  minimal mocking surface (a Feature test should rarely need to mock a
  Repository or Adapter directly)

If a Feature test needs to mock more than 2 UseCases, that's a sign the
Feature is doing too much.
