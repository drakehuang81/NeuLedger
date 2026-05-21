# NeuLedger Architecture Spec

This document is the **source of truth** for layering, naming, and dependency
rules. New code and refactors must conform to this spec; deviations need an
explicit note in code review.

Status: **current architecture** — Phase 5–7 migration completed 2026-05-21.

Layer separation (Domain / Application / Core), the UseCase catalog
(12), the Adapter catalog (5), the Repository pattern via
`SwiftDataStore`, and the BudgetWarningPolicy / LedgerUseCase →
BudgetUseCase §3.1 invariant chain are all in place.

Known follow-ups (intentional, low-risk cleanup):

- Repository interfaces still use the legacy `*Client.swift` /
  `XxxClient` type names instead of `*Repository`. File locations
  match the §8 layout (`Domain/Repositories/`, `Core/Repositories/`)
  and §10 antipatterns are clean — only the type renames remain.
- Some Feature reducers continue to inject Repositories / Adapters
  directly rather than the new UseCases (e.g., `@Dependency(\.account
  Client)` rather than `\.accountUseCase`). §10 does not forbid this,
  so the residual cleanup is ergonomic rather than compliance.
- `TransactionClient.weeklySpending` / `statsSnapshot` / `detailStats`
  remain on the Repository surface as thin pass-throughs to
  `TransactionAnalyticsKernel`. Callsites can switch to the
  architecture-target `AnalyticsUseCase` endpoints as ergonomics
  allow.

See [§9 Migration](#9-migration) for the original Phase 0–7 plan.

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
| **UseCase** | Repository, Adapter, Policy, Domain types, Foundation primitives, **other UseCase only under §3.1 whitelist** | Reducer, View, SwiftData, UIKit, WidgetKit, CloudKit, UserDefaults, UNUserNotificationCenter, Foundation Models — all of these go through Adapters |
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

## 3.1 UseCase → UseCase: Whitelist Only

**Default rule: a UseCase does NOT call another UseCase.** UseCases are
peers, not stacked. Coordination across UseCases belongs in the caller
(usually the Reducer). This keeps each UseCase independently testable,
prevents hidden side-effect chains, and avoids accidental cycles.

Cross-UseCase calls are allowed only in two named scenarios. Any such call
must carry a comment tagging which scenario it is.

### Scenario A: Saga — a business flow spans bounded contexts

Use when one UseCase's job is, by definition, to drive a flow that includes
another UseCase's full chain of effects.

```swift
// SAGA: Recurring tick must trigger the full transaction-record flow
// (including budget evaluation), so we call LedgerUseCase rather than
// touching transactionRepository directly.
RecurringUseCase.tick() {
    for rt in due {
        try await ledgerUseCase.record(Transaction(from: rt))
        try await recurringRepository.markFired(rt.id)
    }
}
```

### Scenario B: Post-condition invariant — A must always be followed by B

Use when the second action is an invariant of the first — never optional,
never something a caller could legitimately skip.

```swift
// INVARIANT: every recorded transaction must be evaluated for budget
// warnings. Cannot rely on individual callers to remember.
LedgerUseCase.record(_ tx: Transaction) async throws {
    try await transactionRepository.add(tx)
    await budgetUseCase.evaluateAfterTransaction(tx)
}
```

### Everything else: refuse and refactor

| If you're tempted to call... | Do this instead |
|---|---|
| Another UseCase to read entity data | Call the underlying Repository directly |
| Another UseCase to read a setting | Call `AppEnvironmentUseCase` (the one wrapper UseCase exception) or its Adapter directly |
| Another UseCase to reuse a calculation | Extract the calculation to a Policy |
| Another UseCase to coordinate two steps for one screen | Let the Reducer coordinate via two `.run` Effects |

### Why AppEnvironmentUseCase is an exception

`AppEnvironmentUseCase` is a **wrapper UseCase** — its job is to give other
UseCases / Reducers a typed concept-shaped surface over UserDefaults
Adapter, Notification Adapter, and System Adapter. Other UseCases reading
preferences through it is fine; it's the difference between
`userSettingsAdapter.bool(.budgetWarningEnabled)` (leaks UserDefaults
knowledge) and `appEnvironmentUseCase.budgetWarningEnabled()` (concept-shaped).

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

## 4.2 Repository Implementation Pattern

Repository **interfaces** stay as TCA `@DependencyClient` structs of closures.
Repository **implementations** (Live) must not touch SwiftData primitives
directly. Both rules are enforced by the design below.

### Three building blocks

1. **`\.modelContainer`** — the `ModelContainer` itself, exposed as a TCA
   dependency. This is the only place `ModelContainer` is registered.
   `SwiftDataStore` may depend on it; **no one else may**.

2. **`PersistentDomainModel`** — protocol that every SwiftData model adopts,
   absorbing all mapping + relationship + lifecycle concerns. This is where
   `ModelContext` is allowed to surface, because mapping fundamentally needs it.

3. **`SwiftDataStore<Domain, SD>`** — generic CRUD struct. Resolves the
   container itself via `@Dependency`; Repositories instantiate it with zero
   arguments. All `ModelContext` usage stays inside this struct's five methods.

### `\.modelContainer` dependency

```swift
// Core/Persistence/ModelContainerKey.swift
import SwiftData
import Dependencies

extension DependencyValues {
    var modelContainer: ModelContainer {
        get { self[ModelContainerKey.self] }
        set { self[ModelContainerKey.self] = newValue }
    }
}

private enum ModelContainerKey: DependencyKey {
    static var liveValue: ModelContainer { makeLiveContainer() }   // current logic from DatabaseClient
    static var testValue: ModelContainer { makeInMemoryContainer() }
}
```

**Rule:** only `SwiftDataStore` may `@Dependency(\.modelContainer)`.
Repository Live, UseCase, Feature, anyone else — forbidden.

### `PersistentDomainModel` protocol

```swift
// Domain layer — zero SwiftData
public protocol DomainConvertible {
    associatedtype DomainModel: Identifiable & Sendable
    func toDomain() -> DomainModel
}

// Core layer — SwiftData OK here, this is the boundary
public protocol PersistentDomainModel: PersistentModel, DomainConvertible
where DomainModel.ID: Sendable & Equatable {

    /// Create a new SD instance and insert into context.
    /// Internally resolves any relationships using the context.
    @discardableResult
    static func from(_ domain: DomainModel, context: ModelContext) -> Self

    /// Apply Domain changes to this SD instance.
    /// Internally resolves any relationship updates using the context.
    func applyChanges(from domain: DomainModel, context: ModelContext)

    /// Cleanup before delete (e.g. clearing inverse relationships).
    /// Default implementation does nothing.
    func prepareForDelete()

    /// Build a predicate that finds this SD by domain id.
    static func idPredicate(_ id: DomainModel.ID) -> Predicate<Self>
}

public extension PersistentDomainModel {
    func prepareForDelete() {}
}
```

`ModelContext` only appears in `from(_:context:)` and `applyChanges(_:context:)`
inside the mapper. It does not escape into Repository or above.

### `SwiftDataStore`

```swift
// Core/Persistence/SwiftDataStore.swift
public struct SwiftDataStore<Domain: Identifiable & Sendable,
                              SD: PersistentDomainModel>: Sendable
    where SD.DomainModel == Domain
{
    @Dependency(\.modelContainer) private var container

    public init() {}

    public func fetchAll(sortBy: [SortDescriptor<SD>] = []) async throws -> [Domain]
    public func fetch(id: Domain.ID) async throws -> Domain?
    public func add(_ domain: Domain) async throws
    public func update(_ domain: Domain) async throws
    public func delete(id: Domain.ID) async throws
}
```

Five methods, generic over any `(Domain, SD)` pair. No escape hatch. No
context exposed.

### Repository Live — zero infrastructure awareness

```swift
extension TransactionRepository: DependencyKey {
    public static var liveValue: TransactionRepository {
        let store = SwiftDataStore<Transaction, SDTransaction>()   // zero args

        return TransactionRepository(
            fetchAll: { try await store.fetchAll(sortBy: [SortDescriptor(\.date, order: .reverse)]) },
            fetch: { try await store.fetch(id: $0) },
            add: { try await store.add($0) },             // mapper handles tag resolution
            update: { try await store.update($0) },       // mapper handles tag resolution
            delete: { try await store.delete(id: $0) },
            search: { query in
                // No ModelContext access. Fetch + filter in Swift.
                let lowered = query.lowercased()
                let all = try await store.fetchAll()
                return all.filter { $0.note?.lowercased().contains(lowered) == true }
            },
            weeklySpending: { accountId, days in
                let all = try await store.fetchAll()
                // ... aggregate in Swift
            }
        )
    }
}
```

Repository Live mentions neither `ModelContainer` nor `ModelContext`.

### Evolution path for custom queries

`search` and `weeklySpending` currently use `store.fetchAll()` + Swift-side
filtering / aggregation. For NeuLedger's scale (hundreds to a few thousand
transactions) this is fine. If profiling later shows it's a bottleneck,
add a specialized method on `SwiftDataStore` via constrained extension:

```swift
extension SwiftDataStore where SD == SDTransaction {
    public func search(_ query: String) async throws -> [Transaction] {
        // Uses predicate directly, still hides ModelContext.
    }
}
```

Repository switches from `store.fetchAll() + filter` to `store.search(query)`;
its public surface is unchanged. No call-site changes anywhere.

### What this design forbids

| Anti-pattern | Why it's banned |
|---|---|
| `@Dependency(\.modelContainer)` in Repository Live | Defeats the whole point — Repository would touch infrastructure |
| `ModelContext(...)` outside `SwiftDataStore` or `PersistentDomainModel` mappers | Same |
| `FetchDescriptor<SD>` returned from a Repository | Leaks SwiftData type upward |
| Repository Live opens a context for "just one custom query" | Add a `SwiftDataStore where SD == X` extension instead |
| Mapper performs business logic (not just translation) | Mappers translate shape only; business rules go in Policy / UseCase |

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
  > Internally calls `accountRepository.add` directly (no §3.1 whitelist
  > reason to route through `AccountUseCase`), then
  > `appEnvironmentUseCase.markOnboardingComplete()`.

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
│   ├── Persistence/                   # ModelContainerKey, SwiftDataStore
│   ├── Mappers/                       # SD*+Mapping.swift (PersistentDomainModel conformances)
│   ├── Repositories/                  # *Repository+Live.swift (uses SwiftDataStore)
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
| `Core/Persistence/DatabaseClient` (struct wrapping ModelContainer + 4 CRUD helpers) | Replace → `\.modelContainer` dependency + `SwiftDataStore<Domain, SD>` generic. CRUD helpers removed; mapping logic moves into `PersistentDomainModel` mappers. |
| `DomainConvertible` only has `toDomain` / `from` | Promote SD-side conformance to `PersistentDomainModel` (adds `applyChanges`, `prepareForDelete`, `idPredicate`) |
| `Core/Clients/TransactionClient+Live` (Repository + UseCase mix) | Split → `Core/Repositories/TransactionRepository+Live` (uses `SwiftDataStore`) + `Application/Ledger/LedgerUseCase+Live` (orchestration) |
| `Core/Clients/AIServiceClient+Live` (already a UseCase but mis-named) | Rename → `Application/AI/AIUseCase+Live` |
| `Core/Clients/SyncClient+Live` | Rename → `Application/CloudSync/CloudSyncUseCase+Live` |
| `Core/Clients/NotificationClient+Live` | Rename → `Core/Adapters/NotificationAdapter+Live` |
| `Core/Clients/WidgetSyncClient+Live` | Rename → `Core/Adapters/WidgetSyncAdapter+Live` |
| `Core/Clients/UserSettingsClient+Live` | Rename → `Core/Adapters/UserSettingsAdapter+Live` |
| `Domain/Clients/*Client.swift` | Move + split → `Domain/Repositories/`, `Domain/Adapters/`, `Domain/UseCases/` |
| Features directly inject Repository / Adapter | Refactor to inject UseCase only |

This is a multi-PR refactor. Suggested ordering:

1. **Persistence foundation** (no behavior change, biggest blast radius):
   introduce `\.modelContainer` + `SwiftDataStore` + `PersistentDomainModel`;
   migrate every existing `*Client+Live` to use it; retire `DatabaseClient`.
   Do this first because every Repository depends on it.
2. **Adapter renames** (low risk): `NotificationClient` → `NotificationAdapter`,
   `UserSettingsClient` → `UserSettingsAdapter`, `WidgetSyncClient` → `WidgetSyncAdapter`.
3. **Promote misnamed UseCases**: `AIServiceClient` → `AIUseCase` (+ split out
   `AIAdapter` for raw Foundation Models calls), `SyncClient` → `CloudSyncUseCase`
   (+ split out `CloudKitSyncAdapter`).
4. **Extract Ledger UseCase**: pull `checkBudgetWarnings` out of
   `TransactionRepository`, create `LedgerUseCase` + `BudgetUseCase`. Update
   Features that record transactions to call `LedgerUseCase.record`.
5. **Introduce remaining UseCases incrementally**, one bounded context per PR.
6. **Folder restructure** (Domain split, new Application folder) — best done
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
| UseCase A calls UseCase B without a §3.1 saga/invariant comment | Refactor: call Repository / Adapter directly, or extract to Policy, or let Reducer coordinate |
| Repository Live has `@Dependency(\.modelContainer)` | Only `SwiftDataStore` may. Repository instantiates `SwiftDataStore<Domain, SD>()` with zero args. |
| `ModelContext` referenced outside `SwiftDataStore` / `PersistentDomainModel` mapper | Move the work to a Store method (or a constrained extension on Store) |
| `FetchDescriptor<SD>` returned from a Repository | Return Domain types only |

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
