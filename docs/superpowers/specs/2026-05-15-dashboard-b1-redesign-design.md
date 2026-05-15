# Dashboard B1 Warm Redesign

**Date**: 2026-05-15
**Status**: Spec — pending approval
**Source design**: `design/source/dashboard-b1.jsx`, `design/screens/02-Dashboard.html`
**Target**: `Features/Sources/Features/Dashboard/`

---

## 1. Goal

Re-implement the Dashboard screen to match the B1 Warm design system. Replace the current top-down list (Balance → Quick Actions → Accounts → Transactions → Insight) with the new layout (Top Bar → Account Chips → Hero Balance → Stats Row → AI Insight Carousel → Transactions). Extend `DashboardFeature` reducer to support per-section loading/error states, account-chip filtering, weekly spending sparkline, snapshot stats, and a 3-card insight carousel.

**Quick Add Sheet is out of scope.** Tab Bar is out of scope (belongs to `MainTabFeature`).

---

## 2. Scope decisions (settled during brainstorming)

| Topic | Decision |
|---|---|
| AI Insight data source | Mock 3 entries baked into `aiServiceClient.liveValue`; schema supports future LLM swap without reducer change |
| Account Chip filter range | Hero / Sparkline / Transactions follow the selection. Stats / Insight remain global |
| Loading visual | Per-section `.redacted(reason: .placeholder)` + shimmer modifier |
| Error visual | Per-section inline `SectionFailureView` with retry button |
| Slice cadence | 7 commits (Slice 0, 1+2 merged, then 3, 4, 5, 6, 7, 8) |
| Quick Add Sheet | Not touched this round |

---

## 3. Reducer & State

### 3.1 State additions

```swift
@ObservableState
struct State: Equatable {
    // ... existing fields preserved ...

    // Chip filter
    var selectedAccountID: Account.ID? = nil       // nil = "All"
    var filteredBalance: Decimal = 0
    var weeklySpending: [Decimal] = []
    var filteredRecent: [Transaction] = []

    // Stats Row (global, not affected by chip)
    var todaySpending: Decimal = 0
    var weekSpending: Decimal = 0
    var savingsPercentage: Double = 0

    // Insight carousel
    var insights: [InsightData] = []
    var insightIndex: Int = 0

    // Transaction row expansion
    var expandedTransactionID: Transaction.ID? = nil

    // Per-section view state
    var heroPhase: SectionPhase = .idle
    var statsPhase: SectionPhase = .idle
    var transactionsPhase: SectionPhase = .idle
    var insightPhase: SectionPhase = .idle
    var accountsPhase: SectionPhase = .idle
}

enum SectionPhase: Equatable {
    case idle
    case loading
    case loaded
    case failed(String)
}

struct InsightData: Equatable, Identifiable, Sendable {
    let id: UUID
    let title: String
    let body: String
    let metric: String
    let metricColor: InsightColor
    let cta: String?
}

enum InsightColor: String, Equatable, Sendable {
    case income, expense, accent, neutral
}
```

### 3.2 Action additions

```swift
enum Action: Equatable {
    // ... existing ...

    case accountChipSelected(Account.ID?)
    case weeklySpendingComputed([Decimal])
    case statsComputed(today: Decimal, week: Decimal, savings: Double)
    case insightsLoaded([InsightData])
    case insightIndexChanged(Int)
    case transactionRowToggled(Transaction.ID)
    case sectionFailed(Section, String)
    case retrySection(Section)

    enum Section: Equatable { case hero, stats, transactions, insight, accounts }
}
```

### 3.3 Reducer rules

1. **Chip switching** — `accountChipSelected(id)` sets `heroPhase` and `transactionsPhase` to `.loading`, then triggers `loadWeeklySpending(scopedTo: id)` and a synchronous recompute of `filteredBalance` + `filteredRecent`. `statsPhase` / `insightPhase` are **not** touched.
2. **No swallow** — every effect catches its own errors and emits `sectionFailed(.xxx, message)`. The matching `SectionPhase` becomes `.failed(message)`.
3. **Retry** — `retrySection(.x)` sets the phase back to `.loading` and re-runs that section's loader. Each effect uses `cancelInFlight: true`.
4. **`.task`** — emits a `.merge` of all section loaders. Each completes independently; one failure does not block the others.
5. **`recentTransactions` vs `filteredRecent`** — both kept. `recentTransactions` is the unfiltered cache (used by stats). `filteredRecent` is what the view renders. When `selectedAccountID == nil` they are equal.
6. **`filteredBalance` semantics** — when `selectedAccountID == nil` it equals `totalBalance`. When set to an account ID it equals `accountBalances[id] ?? 0`. Recomputed synchronously in the reducer on chip selection; no async effect needed.
7. **`AccountChipsStrip` failure UI** — uses the same three-state template via `accountsPhase`. If account fetch fails the chip strip shows a compact retry control instead of chips.

---

## 4. View architecture

### 4.1 `DashboardScreen` composition

```swift
ZStack {
    WarmGradientBackground(variant: .top)
    ScrollView {
        VStack(spacing: 16) {
            DashboardTopBar(store: store)
            AccountChipsStrip(store: store)
            HeroBalanceCard(store: store)
            StatsRow(store: store)
            InsightCarousel(store: store)
            TransactionsSection(store: store)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 120)
    }
    .refreshable { await store.send(.refresh).finish() }
}
.navigationBarHidden(true)
```

### 4.2 File layout

```
Features/Sources/Features/Dashboard/
├── DashboardFeature.swift
├── DashboardScreen.swift             # composition root only
└── Sections/
    ├── DashboardTopBar.swift
    ├── AccountChipsStrip.swift
    ├── HeroBalanceCard.swift
    ├── StatsRow.swift
    ├── InsightCarousel.swift
    └── TransactionsSection.swift
```

### 4.3 Section three-state template

Every section view follows the same pattern — same content shown in all three phases, only wrapped differently:

```swift
GlassContainer(cornerRadius: r, padding: p) {
    switch phase {
    case .idle, .loading:
        content.skeleton(when: true)
    case .loaded:
        content
    case let .failed(msg):
        SectionFailureView(message: msg) { store.send(.retrySection(.x)) }
    }
}
```

---

## 5. Common component changes

### 5.1 New components

| Component | Purpose |
|---|---|
| `Common/Components/PageDots.swift` | Renamed from `OnboardingPageDots`. Shared between Onboarding and Insight Carousel |
| `Common/Components/SkeletonModifier.swift` | `.skeleton(when:)` modifier — `.redacted(reason: .placeholder)` + shimmer animation |
| `Common/Components/SectionFailureView.swift` | Error message + retry button, shared across all dashboard sections |
| `Common/Components/MetricBadge.swift` | Tint pill — used in Hero Net badge and Insight metric |
| `Common/Components/MiniSparkline.swift` | 7-bar 30 pt height chart, takes `[Decimal]` |
| `Common/Components/StatPill.swift` | Uppercase label + monospace value (Stats Row) |
| `Common/Components/AvatarBadge.swift` | 36 pt gradient circle (Top Bar) |

### 5.2 Extended components

| Component | Change |
|---|---|
| `TransactionRow` | Add `isExpanded` flag and tags slot; icon circle bg uses semi-transparent tint |
| `AccountCard` | Add `isActive` styling + chip variant for horizontal strip |
| `InsightCard` | Corner radius 16 → 22; add metric badge slot and CTA slot |
| `EmptyStateView` | Circle 80 → 72 pt; type sizes adjusted to match design |

### 5.3 Unchanged

`GlassContainer`, `TagPill`, `WarmGradientBackground`, `FlowLayout`, `PrimaryButton`, `BalanceDisplay`.

### 5.4 Naming migration

`OnboardingPageDots` → `PageDots`. Update Onboarding's import accordingly in the same slice (Slice 0).

---

## 6. Data flow & client contracts

### 6.1 Effect map

```
.task ──┬─→ loadAccounts ────────→ accountsUpdated → accountBalancesComputed
        ├─→ loadCategories ──────→ categoriesUpdated
        ├─→ loadTransactions ────→ transactionsUpdated → recompute(filtered)
        ├─→ loadWeeklySpending ──→ weeklySpendingComputed
        ├─→ loadStats ───────────→ statsComputed
        └─→ loadInsights ────────→ insightsLoaded

.accountChipSelected(id) ──┬─→ loadWeeklySpending(scopedTo: id)
                           ├─→ filteredBalance recomputed in reducer
                           └─→ filteredRecent recomputed in reducer

.retrySection(.x) ─────────→ same loader as .task, scoped to one section
.refresh ──────────────────→ all section loaders, cancelInFlight: true
```

### 6.2 `transactionClient` additions

```swift
public var weeklySpending: @Sendable (_ accountID: Account.ID?, _ days: Int) async throws -> [Decimal]
public var statsSnapshot: @Sendable () async throws -> StatsSnapshot

public struct StatsSnapshot: Equatable, Sendable {
    public let today: Decimal
    public let week: Decimal
    public let savingsPercentage: Double
}
```

Live impl runs on the `@ModelActor`-isolated context, fetches `SDTransaction` in range, reduces.

### 6.3 `aiServiceClient` additions

```swift
public var generateInsights: @Sendable (_ summary: SpendingSummary) async throws -> [InsightData]
```

`.liveValue` returns 3 hard-coded entries matching design copy. Existing `generateInsight` (single) is left in place; Dashboard now consumes `generateInsights`. Cleanup of the single-method API is deferred to a future PR if no other call sites exist.

### 6.4 `SpendingSummary` extension

```swift
public struct SpendingSummary: Equatable, Sendable {
    public let monthTotal: Decimal
    public let weekTotal: Decimal
    public let topCategory: (name: String, amount: Decimal)?
    public let savingsPercentage: Double
}
```

### 6.5 Concurrency

- All `.task` effects emit via `.merge`. Each runs to completion or `.sectionFailed` independently.
- Chip rapid-switching: `loadWeeklySpending` uses `cancelInFlight: true`, so only the last selection's result lands.
- Pull-to-refresh interleaved with chip selection: same `cancelInFlight: true` strategy across all section loaders.

---

## 7. Slice plan (7 commits)

| # | Slice | Touches | Verifiable after this slice |
|---|---|---|---|
| **0** | Shared primitives | `PageDots`, `SkeletonModifier`, `SectionFailureView`, `MetricBadge`, `MiniSparkline`, `StatPill`, `AvatarBadge`, Onboarding import migration | New components render in standalone Previews; Onboarding still works |
| **1+2** | Skeleton + SectionPhase + Hero + Sparkline | `DashboardFeature` (phases, actions), `DashboardScreen` (composition root), `HeroBalanceCard`, `TransactionClient.weeklySpending` (Domain + Core + tests) | Dashboard shows new layout structure; Hero shows real balance + Net + In/Out + sparkline; other sections still skeleton; per-section retry works for Hero |
| **3** | Top Bar | `DashboardTopBar`, `AvatarBadge` integration | Top Bar shows avatar + greeting + date + 2 icon buttons (AI/Search tap = no-op for now) |
| **4** | Account Chips | `AccountChipsStrip`, `AccountCard` chip variant, reducer `accountChipSelected`, Hero/Transactions subscribe to `selectedAccountID` | Chip selection re-scopes Hero / Sparkline / Transactions; Stats / Insight stay global; rapid switching is race-free |
| **5** | Stats Row | `StatsRow`, `StatPill`, `TransactionClient.statsSnapshot` (Domain + Core + tests) | Stats Row shows Today / This Week / Saved %; per-section retry works |
| **6** | Transactions | `TransactionRow` extension (tags slot, expansion), `TransactionsSection`, reducer `transactionRowToggled` | Shows 6 transactions; rows expand to reveal tags; icon circle uses tint bg |
| **7** | Insight Carousel | `InsightCarousel`, `InsightCard` extension (radius 22 + metric + CTA), `AIServiceClient.generateInsights` (Domain + Core mock + tests), `SpendingSummary` extension | 3 insights swipe-able; `PageDots` reflects index; CTA tap = no-op |
| **8** | Polish | `EmptyStateView` size tweak, per-section empty copy, light/dark mode pass | Empty states for 0 accounts / 0 transactions match design; visual parity across modes |

Slice 0 is a prerequisite for 1+2. Slices 3–7 can run in any order after 1+2 lands. Slice 8 is final polish and depends on 1–7 being complete. Total commits land = 7 (Slice 0, 1+2, 3, 4, 5, 6, 7, 8 — table has 8 rows because 1+2 share one commit).

---

## 8. Testing strategy

### 8.1 Layer coverage

| Layer | Tool | What |
|---|---|---|
| Domain | Swift Testing `@Suite` | `InsightData` Equatable / Codable round-trip; `SectionPhase` exhaustiveness; `SpendingSummary` schema |
| Core (Live clients) | Swift Testing + in-memory SwiftData | `weeklySpending` returns array of correct length with correct daily sums; `statsSnapshot` math correct |
| Feature (Reducer) | TCA `TestStore` | State transitions, effect triggers, phase changes per scenarios below |
| View | SwiftUI `#Preview` + manual screenshot diff against `design/screens/02-Dashboard.html` | Visual parity. No snapshot tests. |

### 8.2 TestStore scenarios per slice

**Slice 1+2** — `.task` walks all phases through `.idle → .loading → .loaded`; failure path keeps other phases untouched; `retrySection(.hero)` resets and re-runs.

**Slice 4** — Initial `selectedAccountID == nil` → `filteredRecent == recentTransactions`. `accountChipSelected(accountA)` → `heroPhase/transactionsPhase = .loading`, `statsPhase/insightPhase` unchanged, `filteredBalance` and `filteredRecent` correct for A. `accountChipSelected(nil)` resets. Rapid A→B→C ends in C-correct state.

**Slice 5** — `statsComputed` updates state. Chip switching does **not** re-emit `loadStats` (test asserts this).

**Slice 6** — `transactionRowToggled(id)` toggles `expandedTransactionID` to id, again to nil. Tap different id replaces.

**Slice 7** — `insightsLoaded(_)` populates 3 entries with `insightIndex == 0`. `insightIndexChanged(2)` updates. `generateInsights` throwing → `insightPhase = .failed`.

**Slice 8** — empty-state branches for `topAccounts.isEmpty` and `recentTransactions.isEmpty`.

### 8.3 TDD policy

- **Reducer / client logic** — TDD required. Failing test → implementation → green.
- **Pure visual work / component extraction** — TDD exempt per `CLAUDE.md`. Preview + visual diff is sufficient.

### 8.4 Commands

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:FeaturesTests/DashboardFeatureTests
```

---

## 9. Out of scope (future PRs)

- Quick Add Sheet redesign with AI extraction preview
- Top Bar AI / Search button real behavior
- Insight CTA deep link destinations
- Real LLM wiring for `generateInsights` (replace mock)
- Tab Bar visual changes (lives in `MainTabFeature`)
- Removing the legacy single-method `generateInsight` from `AIServiceClient`

---

## 10. Open questions

None at spec time. All scope decisions resolved during brainstorming.
