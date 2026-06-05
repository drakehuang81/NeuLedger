# NeuLedger Architecture Spec

This document is the **source of truth** for layering, naming, and dependency
rules. New code and refactors must conform to this spec; deviations need an
explicit note in code review.

Status: **current architecture** — Client layer consolidation completed
2026-06-04 (see §8 History).

The Application layer is six domain **Clients** (`UseCase == Client`); the
Repository layer is dissolved — Client Lives read persistence through
`SwiftDataStore<Domain, SD>` directly. "Client" as a word exists **only** in
the Application layer.

Pending ruling (recorded, not yet decided): `WatchSessionDelegate` records
inbound watch transactions by writing the store directly (pre-existing
behavior). Whether it should route through `ledgerClient.record` to gain the
budget-warning invariant + mirror push is an open product decision.

---

## 1. Layers

```
┌────────────────────────────────────────────────────────┐
│ Presentation    XxxFeature / XxxView (TCA)             │
│                   │ injects Clients only (any number)  │
│                   ▼                                    │
│ Application     XxxClient (= the UseCase layer)        │
│                   │ composes                           │
│                   ├─▶ SwiftDataStore<Domain, SD>       │
│                   ├─▶ XxxAdapter (system APIs)         │
│                   ├─▶ Entity rules (pure logic)        │
│                   └─▶ another Client (§3.1 only)       │
│ Domain          Entity / ValueObject (rich: pure       │
│                 domain rules live as entity methods)   │
│                 + Client / Adapter interfaces.         │
│                 Zero external imports.                 │
│ Infrastructure  SwiftDataStore + Mappers + Adapter     │
│                 Lives + PersistenceBootstrap           │
└────────────────────────────────────────────────────────┘
```

Dependency direction: **outer → inner, never reversed.**

---

## 2. Naming

| Concept | Type Suffix | DI Key Path |
|---|---|---|
| View | `XxxView` | — |
| Reducer | `XxxFeature` | — |
| Client (Application) | `XxxClient` | `\.xxxClient` |
| Adapter | `XxxAdapter` | `\.xxxAdapter` |
| Entity / Value Object | `Xxx` | — |
| SwiftData Model | `SDXxx` | — |
| Domain rule | entity/VO method (pure, e.g. `Budget.evaluate`) | — |

There is no `Repository` and no `UseCase` suffix anymore. A new `XxxClient`
file is legitimate **only** as a domain-shaped Application surface (see §5
for the catalog); persistence access goes through `SwiftDataStore`, system
APIs through an `XxxAdapter`.

---

## 3. Dependency Rules (Strict)

| Who | May depend on | May NOT depend on |
|---|---|---|
| **Feature** | Clients (any number), TCA built-ins (`\.dismiss`, `\.continuousClock`, `\.uuid`, `\.openURL`, `\.date`) | Adapters, `SwiftDataStore`, `\.modelContainer`, system APIs |
| **Client Live** | `SwiftDataStore`, Adapters, Domain types (incl. entity rules), another Client (§3.1 whitelist only) | `ModelContext` / SwiftData primitives, UIKit/WidgetKit/etc. directly |
| **Adapter** | System APIs, Domain types | Other Adapters, Clients, `SwiftDataStore` |
| **SwiftDataStore / Mapper** | `\.modelContainer`, `ModelContext` | Business logic |
| **Entity rule** | Pure Swift (Foundation OK) | Anything async / throws IO |

**Rationale for strict Feature → Client only:** every screen-driven mutation
or composed query funnels through a Client. Cross-cutting changes (audit
log, telemetry, optimistic UI) touch six Clients, not thirty reducers.

**One concession:** pure system-API calls that only affect the running app
(e.g., `UIApplication.shared.open` for an outbound URL) may stay inline in
`View` if a Client wrapper would be pure overhead. Anything that **writes to
user data or stored state must go through a Client**.

**Infrastructure-internal exception (§E.2):** components that *are* the
mirror/sync pipeline (`WatchContextBuilder`, `WatchSyncObserver`,
`WatchMidnightTimer`, `WatchSessionDelegate`) live in `Core/Adapters/Watch/`
and may read/write `SwiftDataStore` directly — same layer, no rule crossed.

---

## 3.1 Client → Client: Whitelist Only

Default rule: Clients are peers, not stacked. Coordination across Clients
belongs in the caller (usually the Reducer, via separate `.run` effects).
Cross-Client calls carry a comment naming the scenario.

Current whitelist — exactly one entry:

```swift
// INVARIANT(§3.1): every recorded/updated transaction must be evaluated
// for budget warnings. Cannot rely on individual callers to remember.
LedgerClient.record / .update → PlanningClient.evaluateAfterTransaction
```

Everything else: refuse and refactor.

| If you're tempted to call... | Do this instead |
|---|---|
| Another Client to read entity data | Read `SwiftDataStore` directly (Application layer is allowed to) |
| Another Client to read a setting | Read `userSettingsAdapter` directly |
| Another Client to reuse a calculation | Extract it to a pure entity/VO method |
| Another Client to coordinate two steps for one screen | Let the Reducer coordinate via two `.run` effects |

Historical note: the former `RecurringUseCase.tick → LedgerUseCase.record`
saga is now an internal call inside `LedgerClient` (recurring lives in the
ledger context), and the former `AppEnvironmentUseCase` wrapper exception is
gone (each Client reads its own settings keys through `userSettingsAdapter`).

---

## 4. Persistence Pattern

Three building blocks; `ModelContext` never escapes them.

1. **`\.modelContainer`** — the `ModelContainer` as a TCA dependency.
   Only `SwiftDataStore` may `@Dependency(\.modelContainer)`.
2. **`PersistentDomainModel`** — protocol every SD model adopts
   (`from(_:context:)`, `applyChanges(from:context:)`, `prepareForDelete()`,
   `idPredicate(_:)`). Mapping and relationship lifecycle live here
   (e.g., tag disassociation on delete).
3. **`SwiftDataStore<Domain, SD>`** — generic CRUD struct
   (`fetchAll(sortBy:)`, `fetch(id:)`, `add`, `update`, `delete(id:)`).
   Client Lives instantiate it with zero arguments — via the
   **per-aggregate aliases** in `Core/Persistence/Stores.swift`
   (`TransactionStore`, `AccountStore`, `CategoryStore`, `TagStore`,
   `BudgetStore`, `CarrierStore`, `RecurringTransactionStore`): the
   Domain ↔ SD pairing is declared once, and call sites never spell
   SwiftData vocabulary.

Custom queries start as `store.fetchAll()` + Swift-side filtering. If
profiling shows a bottleneck, add a `SwiftDataStore where SD == X`
constrained extension — call sites don't change.

**`PersistenceBootstrap`** (`Core/Persistence/`) owns container construction
and first-launch seeding (default categories + Cash account). It is
infrastructure, not an Adapter, and nothing above the Infrastructure layer
touches it.

Legal `ModelContext` sites — the closed list: `SwiftDataStore`,
`PersistentDomainModel` mappers, `PersistenceBootstrap` (seeding),
`CloudKitSyncAdapter`, `TransactionAnalyticsKernel`, and the
`Core/Adapters/Watch/` pipeline via `SwiftDataStore`.

---

## 5. Client Catalog (6 + 1 watchOS)

Each Client: interface in `Domain/Clients/` (TCA `@DependencyClient` struct
of `@Sendable` closures, `testValue = Self()`), Live in
`Application/<Context>/` conforming to `DependencyKey`.

### 🧾 `LedgerClient` — facts on the books

Five sections (`// MARK:`), ~35 closures. Live splits across
`LedgerClient+Live{,Accounts,Catalog,Recurring,Export}.swift`.

- **Transactions** — `record` / `update` / `delete` / `fetch` /
  `listRecent(limit:)` / `listAll(filter:)` / `search` (reads return
  `EnrichedTransaction`)
- **Accounts** — `setupAccounts` / `createAccount` / `updateAccount` /
  `archiveAccount` / `unarchiveAccount` / `deleteAccount` / `listAccounts` /
  `listActiveAccounts` / `balance(id:)` / `balances` /
  `defaultAccountId` / `setDefaultAccountId`
- **Catalog** — `listCategories(type?)` / category CRUD / `listTags` / tag CRUD
- **Recurring** — `listRecurring` / recurring CRUD / `tick()`
- **Export** — `exportCSV()` (writes into a unique temp subdirectory;
  user-visible filename stays `NeuLedger_export.csv`)

Internal invariants (commented + tested):
1. `record`/`update` → `planningClient.evaluateAfterTransaction` (§3.1)
2. `record`/`update`/`delete` → Widget/Watch mirror push
3. `tick()` → internal `record` (full chain applies to recurring fires)
4. recurring CRUD → schedules/cancels recurring reminders
   (`notificationAdapter`)
5. accounts with transactions archive-only; `isDefault` categories
   undeletable; tag deletion disassociates transactions
6. `setupAccounts` does **not** write the onboarding flag (that belongs to
   `PlatformClient`; `OnboardingFeature` calls both explicitly)

Live dependencies: `SwiftDataStore` ×5, `planningClient` (invariant),
`widgetSyncAdapter`, `watchBridgeAdapter`, `notificationAdapter`,
`userSettingsAdapter`.

### 💰 `PlanningClient` — constraints on future spending

`listAll` / `listActive` / CRUD / `currentStatus(of:)` /
`evaluateAfterTransaction` (`Budget.evaluate` entity rule + notificationAdapter) /
warning prefs (`warningEnabled` / `warningThreshold` + setters — owns its
own settings keys).

### 📊 `InsightsClient` — read-only projections of the books

`todayStats(referenceDate:)` / `weeklySparkline(accountId:)` /
`dailyBars(range:)` / `categoryProportions(range:)` /
`budgetGauges(accountId:)` / `detailStats(transaction:)` /
`generateAIInsight` / `generateInsights` / `answerFinancialQuestion`
(natural-language reads, incl. `QueryTransactionsTool`) / `isAIAvailable`.
Live composes `TransactionAnalyticsKernel` + `AIAdapter` + `InsightCache`.
Deleting this entire context loses no data.

### 🤖 `CaptureClient` — input assistance before the books

`extractFromText` / `extractFromVoice` / `suggestCategories` / `isAvailable`
/ voice session (`requestVoicePermission` / `startVoiceSession` /
`stopVoiceSession` — forwards `speechAdapter`). Produces drafts
(`ExtractedTransaction`) only; Features pass drafts to `ledgerClient.record`.
Insights vs Capture split is by **direction** (read projection vs write
assist), not by technology.

### 🏷️ `CarrierClient` — Taiwan e-invoice carrier custody

`listAll` / CRUD / `setActiveForWidget` / `activeForWidget`. CRUD and
activation reload the carrier widget internally (post-condition).

### 🛠️ `PlatformClient` — the app's own runtime environment

- **Preferences** — `accessoryMode` / `reminderTime` / `dailyReminderEnabled`
  / `hasCompletedOnboarding` / `markOnboardingComplete` / `showAccessoryBar`
  (+ setters); watch pairing surface: `watchPaired` / `watchAppInstalled` /
  `watchDefaultAccountId` / `setWatchDefaultAccountId`
- **Notification** — `requestNotificationPermission` /
  `notificationsAuthorized` / `scheduleDailyReminder` / `cancelDailyReminder`
  / `pendingRecurringConfirmations` (stream)
- **Sync** — `syncAvailable` / `syncEnabled` / `lastSyncedAt` /
  `enableSync` (progress stream) / `requestSyncNow` / `wipeAllSyncData`
- **Routing** — `parseLink(URL)` / `canSkipOnboarding` /
  `resolveRecurringConfirmation(id)` → `RouteLinkDestination`
- **System** — `openAppSettings`

### ⌚️ `WatchLedgerClient` (watchOS target only)

The watch's view of the ledger: `activeAccounts` / `categories(type:)`
(cache-backed snapshot reads) + `record` (forwards a `TransactionDraft` to
the iPhone via `WatchSessionGateway`). Registered by
`WatchDependencies.register`; never binds to the 35-method `LedgerClient`.

---

## 6. Adapter Catalog (7)

| Adapter | Wraps |
|---|---|
| `UserSettingsAdapter` | `UserDefaults` (`SettingsKey` raw values are persisted — never rename them) |
| `NotificationAdapter` | `UNUserNotificationCenter` + warning state + recurring reminders + `pendingConfirmations` stream |
| `WidgetSyncAdapter` | App Group `UserDefaults` + `WidgetCenter` reloads |
| `AIAdapter` | Foundation Models (`SystemLanguageModel` / `LanguageModelSession`) |
| `CloudKitSyncAdapter` | `NSPersistentCloudKitContainer` lifecycle + `lastSyncedAt` |
| `SpeechAdapter` | Speech recognition session (permission / start / stop) |
| `WatchBridgeAdapter` | WatchConnectivity pairing + snapshot push |

---

## 7. File / Folder Layout

```
Features/Sources/
├── Domain/                      # Pure. No external imports.
│   ├── Entities/  ValueObjects/  Enums/
│   ├── Clients/                 # 6 Client interfaces
│   └── Adapters/                # 7 Adapter interfaces
│
├── Core/                        # Infrastructure
│   ├── Persistence/             # PersistenceBootstrap, ModelContainerKey,
│   │                            # SwiftDataStore, PersistentDomainModel, Models/
│   ├── Mappers/                 # SD*+Mapping.swift
│   ├── Analytics/               # TransactionAnalyticsKernel
│   └── Adapters/                # *Adapter+Live.swift (+ Watch/ pipeline)
│
├── Application/                 # Client Lives (same SPM target as Core)
│   ├── Ledger/  Planning/  Insights/  Capture/  Carrier/  Platform/
│
├── WatchFeatures/               # watchOS presentation + WatchLedgerClient
├── Common/                      # Design system, shared SwiftUI components
└── Features/                    # iOS presentation (TCA Reducers + Views)
```

---

## 8. History

Two migrations shaped this architecture; both specs/plans are retained as
records:

1. **2026-05-21 — Clean Architecture + DDD migration** (Phase 0–7):
   introduced `SwiftDataStore` / `PersistentDomainModel`, Adapter renames,
   12 UseCases, folder split. Plan:
   `docs/superpowers/plans/2026-05-20-architecture-migration.md`.
2. **2026-06-04 — Client layer consolidation**: `UseCase == Client`
   decision; 12 UseCases + 8 repositories consolidated into 6 domain
   Clients (+ `WatchLedgerClient`); Repository layer dissolved;
   `DatabaseClient` → `PersistenceBootstrap`. Spec:
   `docs/superpowers/specs/2026-06-04-client-layer-consolidation-design.md`;
   plan (incl. full retrospective):
   `docs/superpowers/plans/2026-06-04-client-layer-consolidation.md`.

---

## 9. Anti-Patterns

| Smell | What to do instead |
|---|---|
| Reducer imports `SwiftData` or `UserDefaults` | Go through a Client |
| Feature injects an Adapter or `SwiftDataStore` | Go through a Client |
| Client named after a screen (`DashboardClient`) | Name around a domain concept |
| Client A calls Client B without a §3.1 invariant comment | Read the store/adapter directly, extract a Policy, or let the Reducer coordinate |
| Adapter calls another Adapter / a Client | Compose inside a Client Live |
| Entity method does IO / `async throws` | That's Client logic — entities stay pure |
| New ambiguous `XxxClient` outside §5 catalog | Decide: does it belong to an existing context? New contexts need a spec note |
| `@Dependency(\.modelContainer)` outside `SwiftDataStore` | Instantiate `SwiftDataStore<Domain, SD>()` instead |
| `ModelContext` outside the §4 closed list | Move the work into a Store method or constrained extension |
| `FetchDescriptor<SD>` / SD types crossing above Infrastructure | Return Domain types only |
| Mapper performs business logic | Mappers translate shape only; rules go on the entity / in a Client |
| Fixed shared temp-file paths | Unique subdirectory per operation (see `exportCSV`) |

---

## 10. Testability

- **Entity rules** (e.g. `Budget.evaluate`): pure function tests — fastest, no setup
- **Client Live**: in-memory `\.modelContainer` (seed via `SwiftDataStore`)
  + adapter spies via `withDependencies` — see `LedgerClientLiveTests`
- **Adapter Live**: integration tests against real system APIs (sparingly)
- **Feature**: `TestStore` with **Client closures** overridden — minimal
  mocking surface

Hard-won test rules (full retrospective in the 2026-06-04 plan):

- `@DependencyClient` default values (`= { nil }`) are production fallbacks;
  `testValue` closures stay unimplemented — stub **every** closure the
  reducer path touches.
- TCA `Scope` parents execute child paths: switching a child's dependencies
  means updating the **parent feature's tests** too (grep "who Scopes this
  feature" first).
- Tests sharing the simulator process must not write fixed shared file
  paths (parallel suites race).
- Long test sessions degrade simulators; reset with
  `xcrun simctl --set testing delete all` when flakes cluster.

If a Feature test needs to mock more than 2 Clients, the Feature is doing
too much.
