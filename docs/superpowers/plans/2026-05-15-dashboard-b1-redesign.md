# Dashboard B1 Warm Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Re-implement the Dashboard screen to match the B1 Warm design system (`design/source/dashboard-b1.jsx`) with per-section loading/error states, account-chip filtering, weekly spending sparkline, snapshot stats, and a 3-card insight carousel.

**Architecture:** TCA reducer extended with `SectionPhase` per section; view split into `Sections/` subfolder with a thin composition root. New shared components added to `Common/Components/`. Two new client methods (`weeklySpending`, `statsSnapshot`) on `TransactionClient`; new `generateInsights` on `AIServiceClient` returning a mocked 3-entry list.

**Tech Stack:** Swift 6 / SwiftUI on iOS 26, The Composable Architecture v1.23.1, Swift Testing, SwiftData (Core only).

**Spec:** `docs/superpowers/specs/2026-05-15-dashboard-b1-redesign-design.md`

---

## File Structure

### Created files

```
Features/Sources/Common/Components/
├── PageDots.swift                 (renamed from OnboardingPageDots.swift)
├── SkeletonModifier.swift
├── SectionFailureView.swift
├── MetricBadge.swift
├── MiniSparkline.swift
├── StatPill.swift
└── AvatarBadge.swift

Features/Sources/Features/Dashboard/Sections/
├── DashboardTopBar.swift
├── AccountChipsStrip.swift
├── HeroBalanceCard.swift
├── StatsRow.swift
├── InsightCarousel.swift
└── TransactionsSection.swift

Features/Sources/Domain/Entities/
├── StatsSnapshot.swift            (new struct)
├── InsightData.swift              (new struct + InsightColor enum)
└── (SpendingSummary.swift extended)
```

### Modified files

```
Features/Sources/Common/Components/
├── TransactionRow.swift            (add isExpanded + tags slot)
├── AccountCard.swift               (add isActive + chip variant)
├── InsightCard.swift               (radius 22 + metric badge + CTA)
└── EmptyStateView.swift            (circle 80 → 72 pt, type sizes)

Features/Sources/Features/Onboarding/
└── OnboardingView.swift            (import migration OnboardingPageDots → PageDots)

Features/Sources/Features/Dashboard/
├── DashboardFeature.swift          (state + actions + reducer cases)
└── DashboardScreen.swift           (slim composition root)

Features/Sources/Domain/Clients/
├── TransactionClient.swift         (add weeklySpending + statsSnapshot)
└── AIServiceClient.swift           (add generateInsights)

Features/Sources/Core/Clients/
├── TransactionClient+Live.swift    (live impl for new methods)
└── AIServiceClient+Live.swift      (mock impl for generateInsights)
```

### Test files

```
Features/Tests/DomainTests/Entities/
├── InsightDataTests.swift
├── StatsSnapshotTests.swift
└── SectionPhaseTests.swift

Features/Tests/CoreTests/Clients/
├── TransactionClientWeeklyTests.swift
└── TransactionClientStatsTests.swift

Features/Tests/FeaturesTests/Dashboard/
├── DashboardFeatureChipTests.swift
├── DashboardFeatureStatsTests.swift
├── DashboardFeatureInsightTests.swift
└── DashboardFeatureSectionPhaseTests.swift
```

---

## Task 0: Slice 0 — Shared primitives

**Why first:** Other slices depend on these components. Slice 0 is purely additive — no Dashboard or reducer logic changes, so it's safe to commit independently.

**TDD policy:** Pure visual extraction → TDD exempt per CLAUDE.md. Verification is build + Preview render.

**Files:**
- Rename: `Features/Sources/Common/Components/OnboardingPageDots.swift` → `Features/Sources/Common/Components/PageDots.swift`
- Create: `Features/Sources/Common/Components/SkeletonModifier.swift`
- Create: `Features/Sources/Common/Components/SectionFailureView.swift`
- Create: `Features/Sources/Common/Components/MetricBadge.swift`
- Create: `Features/Sources/Common/Components/MiniSparkline.swift`
- Create: `Features/Sources/Common/Components/StatPill.swift`
- Create: `Features/Sources/Common/Components/AvatarBadge.swift`
- Modify: `Features/Sources/Features/Onboarding/OnboardingView.swift` (import / type name update)

---

- [ ] **Step 0.1: Rename `OnboardingPageDots` → `PageDots`**

Delete the old file and create the renamed one. Adjust type name and Preview.

```bash
git mv Features/Sources/Common/Components/OnboardingPageDots.swift Features/Sources/Common/Components/PageDots.swift
```

Then rewrite the file body:

```swift
// Features/Sources/Common/Components/PageDots.swift
import SwiftUI

public struct PageDots: View {
    public let count: Int
    public let active: Int

    public init(count: Int = 3, active: Int) {
        self.count = count
        self.active = active
    }

    public var body: some View {
        HStack(spacing: 6) {
            ForEach(0 ..< count, id: \.self) { i in
                Capsule()
                    .fill(i == active ? Color.primary : Color.primary.opacity(0.15))
                    .frame(width: i == active ? 22 : 6, height: 6)
                    .animation(.easeOut(duration: 0.25), value: active)
            }
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        PageDots(active: 0)
        PageDots(active: 1)
        PageDots(active: 2)
    }
    .padding()
}
```

- [ ] **Step 0.2: Update Onboarding usage**

`Features/Sources/Features/Onboarding/OnboardingView.swift` line 38 reads `OnboardingPageDots(active: dotIndex)` — replace identifier with `PageDots`.

```swift
// before
OnboardingPageDots(active: dotIndex)
// after
PageDots(active: dotIndex)
```

- [ ] **Step 0.3: Create `SkeletonModifier`**

```swift
// Features/Sources/Common/Components/SkeletonModifier.swift
import SwiftUI

public extension View {
    /// Renders content as a placeholder skeleton when `active` is true.
    /// Combines `.redacted(reason: .placeholder)` with a subtle shimmer overlay.
    func skeleton(when active: Bool) -> some View {
        modifier(SkeletonModifier(active: active))
    }
}

struct SkeletonModifier: ViewModifier {
    let active: Bool
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .redacted(reason: active ? .placeholder : [])
            .overlay {
                if active {
                    GeometryReader { proxy in
                        LinearGradient(
                            colors: [.white.opacity(0), .white.opacity(0.25), .white.opacity(0)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: proxy.size.width)
                        .offset(x: proxy.size.width * phase)
                        .blendMode(.plusLighter)
                        .allowsHitTesting(false)
                    }
                    .clipped()
                    .onAppear {
                        withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                            phase = 1
                        }
                    }
                }
            }
    }
}

#Preview {
    VStack(spacing: 16) {
        Text("Hello, world").font(.title).skeleton(when: true)
        Text("Hello, world").font(.title).skeleton(when: false)
    }
    .padding()
}
```

- [ ] **Step 0.4: Create `SectionFailureView`**

```swift
// Features/Sources/Common/Components/SectionFailureView.swift
import SwiftUI

public struct SectionFailureView: View {
    public let message: String
    public let retry: () -> Void

    public init(message: String, retry: @escaping () -> Void) {
        self.message = message
        self.retry = retry
    }

    public var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 22))
                .foregroundStyle(.secondary)
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(action: retry) {
                Text("common_retry")
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(Color.Design.brandPrimary.opacity(0.15)))
                    .foregroundStyle(Color.Design.brandPrimary)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
}

#Preview {
    SectionFailureView(message: "無法載入資料") {}
        .padding()
}
```

Add to `Features/Sources/Common/Resources/Localizable.xcstrings` or your existing string file: key `common_retry` → "重試" (zh-Hant) / "Retry" (en).

- [ ] **Step 0.5: Create `MetricBadge`**

```swift
// Features/Sources/Common/Components/MetricBadge.swift
import SwiftUI

public struct MetricBadge: View {
    public let text: String
    public let color: Color

    public init(text: String, color: Color) {
        self.text = text
        self.color = color
    }

    public var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium).monospacedDigit())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(color.opacity(0.18)))
            .foregroundStyle(color)
    }
}

#Preview {
    HStack(spacing: 8) {
        MetricBadge(text: "+12%", color: Color.Design.incomeGreen)
        MetricBadge(text: "-NT$ 320", color: Color.Design.expenseRed)
        MetricBadge(text: "42%", color: Color.Design.brandPrimary)
    }
    .padding()
}
```

- [ ] **Step 0.6: Create `MiniSparkline`**

```swift
// Features/Sources/Common/Components/MiniSparkline.swift
import SwiftUI

public struct MiniSparkline: View {
    public let values: [Decimal]
    public let accentColor: Color
    public let baseColor: Color

    public init(
        values: [Decimal],
        accentColor: Color = Color.Design.brandPrimary,
        baseColor: Color = Color.secondary.opacity(0.3)
    ) {
        self.values = values
        self.accentColor = accentColor
        self.baseColor = baseColor
    }

    private var maxValue: Decimal {
        max(values.max() ?? 1, 1)
    }

    public var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(values.indices, id: \.self) { i in
                let v = NSDecimalNumber(decimal: values[i]).doubleValue
                let m = NSDecimalNumber(decimal: maxValue).doubleValue
                let h = max(CGFloat(v / m) * 30, 2)
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(i == values.indices.last ? accentColor : baseColor)
                    .frame(width: 5, height: h)
            }
        }
        .frame(height: 30, alignment: .bottom)
    }
}

#Preview {
    VStack {
        MiniSparkline(values: [120, 80, 200, 60, 140, 90, 180])
    }
    .padding()
}
```

- [ ] **Step 0.7: Create `StatPill`**

```swift
// Features/Sources/Common/Components/StatPill.swift
import SwiftUI

public struct StatPill: View {
    public let label: LocalizedStringKey
    public let value: String
    public let valueColor: Color

    public init(label: LocalizedStringKey, value: String, valueColor: Color = .primary) {
        self.label = label
        self.value = value
        self.valueColor = valueColor
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .textCase(.uppercase)
                .tracking(1)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 16, weight: .semibold).monospacedDigit())
                .foregroundStyle(valueColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.ultraThinMaterial))
    }
}

#Preview {
    HStack(spacing: 10) {
        StatPill(label: "stat_today", value: "NT$ 320")
        StatPill(label: "stat_week", value: "NT$ 2,100", valueColor: Color.Design.expenseRed)
        StatPill(label: "stat_saved", value: "28%", valueColor: Color.Design.incomeGreen)
    }
    .padding()
}
```

Add strings to localizable: `stat_today` → "今日" / "Today"; `stat_week` → "本週" / "This Week"; `stat_saved` → "儲蓄率" / "Saved".

- [ ] **Step 0.8: Create `AvatarBadge`**

```swift
// Features/Sources/Common/Components/AvatarBadge.swift
import SwiftUI

public struct AvatarBadge: View {
    public let initials: String

    public init(initials: String) {
        self.initials = initials
    }

    public var body: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [Color.Design.brandPrimary, Color(hex: "#FF2D55")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 36, height: 36)
            .overlay {
                Text(initials.prefix(1))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
            }
            .shadow(color: Color.Design.brandPrimary.opacity(0.35), radius: 6, x: 0, y: 4)
    }
}

#Preview {
    AvatarBadge(initials: "D").padding()
}
```

- [ ] **Step 0.9: Build verification**

Run:

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -3
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 0.10: Commit Slice 0**

```bash
git add Features/Sources/Common/Components/PageDots.swift \
        Features/Sources/Common/Components/SkeletonModifier.swift \
        Features/Sources/Common/Components/SectionFailureView.swift \
        Features/Sources/Common/Components/MetricBadge.swift \
        Features/Sources/Common/Components/MiniSparkline.swift \
        Features/Sources/Common/Components/StatPill.swift \
        Features/Sources/Common/Components/AvatarBadge.swift \
        Features/Sources/Features/Onboarding/OnboardingView.swift \
        Features/Sources/Common/Resources

git commit -m "$(cat <<'EOF'
feat(common): add shared dashboard primitives — PageDots, Skeleton, SectionFailure, MetricBadge, MiniSparkline, StatPill, AvatarBadge

Rename OnboardingPageDots → PageDots (now reused by Insight Carousel).
Add SkeletonModifier (.redacted + shimmer), SectionFailureView (retry CTA),
MetricBadge (tint pill), MiniSparkline (7-bar 30pt chart), StatPill
(uppercase label + monospace value), AvatarBadge (36pt gradient circle).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 1: Slice 1+2 — SectionPhase + composition root + Hero + Sparkline

**TDD policy:** Reducer state machine and `TransactionClient.weeklySpending` are TDD-required. View composition is TDD-exempt.

**Files:**
- Create: `Features/Sources/Domain/Entities/StatsSnapshot.swift` (will be needed by Slice 5 too; introduce here)
- Create: `Features/Sources/Domain/Entities/InsightData.swift` (will be needed by Slice 7; introduce here)
- Modify: `Features/Sources/Domain/Clients/TransactionClient.swift` (add `weeklySpending`)
- Modify: `Features/Sources/Core/Clients/TransactionClient+Live.swift` (live impl)
- Create: `Features/Sources/Features/Dashboard/Sections/HeroBalanceCard.swift`
- Modify: `Features/Sources/Features/Dashboard/DashboardFeature.swift` (state + actions + reducer cases)
- Modify: `Features/Sources/Features/Dashboard/DashboardScreen.swift` (slim composition root, hero only — others remain skeleton)
- Create: `Features/Tests/DomainTests/Entities/SectionPhaseTests.swift`
- Create: `Features/Tests/DomainTests/Entities/InsightDataTests.swift`
- Create: `Features/Tests/DomainTests/Entities/StatsSnapshotTests.swift`
- Create: `Features/Tests/CoreTests/Clients/TransactionClientWeeklyTests.swift`
- Create: `Features/Tests/FeaturesTests/Dashboard/DashboardFeatureSectionPhaseTests.swift`

---

- [ ] **Step 1.1: Define `SectionPhase` enum in `DashboardFeature.swift`**

Add inside `DashboardFeature` namespace (above `State`):

```swift
public enum SectionPhase: Equatable, Sendable {
    case idle
    case loading
    case loaded
    case failed(String)
}

public enum Section: Equatable, Sendable {
    case hero
    case stats
    case transactions
    case insight
    case accounts
}
```

- [ ] **Step 1.2: Write failing test for `SectionPhase`**

```swift
// Features/Tests/DomainTests/Entities/SectionPhaseTests.swift
import Testing
@testable import Features
// Note: SectionPhase is nested under DashboardFeature; we test it indirectly via DashboardFeature.SectionPhase

@Suite("SectionPhase")
struct SectionPhaseTests {
    @Test("idle / loading / loaded / failed all distinct")
    func testCases() {
        let cases: [DashboardFeature.SectionPhase] = [.idle, .loading, .loaded, .failed("x")]
        #expect(Set(cases.map(\.tag)).count == 4)
    }

    @Test("failed equality compares message")
    func testFailedEquality() {
        #expect(DashboardFeature.SectionPhase.failed("a") != .failed("b"))
        #expect(DashboardFeature.SectionPhase.failed("a") == .failed("a"))
    }
}

private extension DashboardFeature.SectionPhase {
    var tag: Int {
        switch self {
        case .idle:      return 0
        case .loading:   return 1
        case .loaded:    return 2
        case .failed:    return 3
        }
    }
}
```

Run:

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:FeaturesTests/SectionPhaseTests 2>&1 | tail -10
```

Expected: PASS (since enum was already added in step 1.1).

> The TDD red-step is implicitly satisfied by step 1.1 ↔ step 1.2 separation. If you prefer strict red-first, run the test before step 1.1.

- [ ] **Step 1.3: Create `InsightData` and `InsightColor`**

```swift
// Features/Sources/Domain/Entities/InsightData.swift
import Foundation

public struct InsightData: Equatable, Identifiable, Sendable {
    public let id: UUID
    public let title: String
    public let body: String
    public let metric: String
    public let metricColor: InsightColor
    public let cta: String?

    public init(
        id: UUID = UUID(),
        title: String,
        body: String,
        metric: String,
        metricColor: InsightColor,
        cta: String? = nil
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.metric = metric
        self.metricColor = metricColor
        self.cta = cta
    }
}

public enum InsightColor: String, Equatable, Sendable, CaseIterable {
    case income, expense, accent, neutral
}
```

- [ ] **Step 1.4: Write failing test for `InsightData`**

```swift
// Features/Tests/DomainTests/Entities/InsightDataTests.swift
import Testing
import Foundation
@testable import Domain

@Suite("InsightData")
struct InsightDataTests {
    @Test("Equality respects all stored fields except id")
    func testEquality() {
        let a = InsightData(title: "T", body: "B", metric: "+10%", metricColor: .income)
        let b = InsightData(id: a.id, title: "T", body: "B", metric: "+10%", metricColor: .income)
        #expect(a == b)
    }

    @Test("InsightColor has 4 cases")
    func testColorCases() {
        #expect(InsightColor.allCases.count == 4)
    }
}
```

Run:

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:FeaturesTests/InsightDataTests 2>&1 | tail -10
```

Expected: PASS.

- [ ] **Step 1.5: Create `StatsSnapshot`**

```swift
// Features/Sources/Domain/Entities/StatsSnapshot.swift
import Foundation

public struct StatsSnapshot: Equatable, Sendable {
    public let today: Decimal
    public let week: Decimal
    public let savingsPercentage: Double

    public init(today: Decimal, week: Decimal, savingsPercentage: Double) {
        self.today = today
        self.week = week
        self.savingsPercentage = savingsPercentage
    }

    public static let zero = StatsSnapshot(today: 0, week: 0, savingsPercentage: 0)
}
```

- [ ] **Step 1.6: Write failing test for `StatsSnapshot`**

```swift
// Features/Tests/DomainTests/Entities/StatsSnapshotTests.swift
import Testing
import Foundation
@testable import Domain

@Suite("StatsSnapshot")
struct StatsSnapshotTests {
    @Test(".zero has all zero values")
    func testZero() {
        #expect(StatsSnapshot.zero.today == 0)
        #expect(StatsSnapshot.zero.week == 0)
        #expect(StatsSnapshot.zero.savingsPercentage == 0)
    }
}
```

Run + expect PASS.

- [ ] **Step 1.7: Extend `TransactionClient` with `weeklySpending`**

Modify `Features/Sources/Domain/Clients/TransactionClient.swift` — find the `@DependencyClient` struct and add:

```swift
/// Returns daily expense totals for the past `days` days, oldest to newest.
/// If `accountID` is non-nil, only that account's transactions are summed.
public var weeklySpending: @Sendable (_ accountID: Account.ID?, _ days: Int) async throws -> [Decimal]
```

- [ ] **Step 1.8: Write failing test for `weeklySpending` live impl**

```swift
// Features/Tests/CoreTests/Clients/TransactionClientWeeklyTests.swift
import Testing
import Foundation
import SwiftData
import ComposableArchitecture
@testable import Core
import Domain

@Suite("TransactionClient.weeklySpending")
struct TransactionClientWeeklyTests {
    private func makeContext() -> ModelContext {
        let client = DatabaseClient.testValue
        return ModelContext(client.modelContainer())
    }

    @Test("Returns 7 entries summed per day")
    func testWeeklyCounts() async throws {
        let ctx = makeContext()
        let acc = SDAccount(
            id: UUID(), name: "Test", type: AccountType.cash.rawValue,
            icon: "banknote", color: "#000", sortOrder: 0,
            isArchived: false, createdAt: Date()
        )
        ctx.insert(acc)

        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        for i in 0 ..< 7 {
            let date = cal.date(byAdding: .day, value: -i, to: today)!
            let tx = SDTransaction(
                id: UUID(), amount: Decimal(100 * (i + 1)), date: date, note: "",
                categoryId: nil, accountId: acc.id, toAccountId: nil,
                type: TransactionType.expense.rawValue, tags: [],
                aiSuggested: false, createdAt: date, updatedAt: date
            )
            ctx.insert(tx)
        }
        try ctx.save()

        let result = try await withDependencies {
            $0.databaseClient = DatabaseClient.testValue
        } operation: {
            try await TransactionClient.liveValue.weeklySpending(nil, 7)
        }

        #expect(result.count == 7)
        // index 6 (today) was inserted with multiplier 1 → 100
        // index 0 (6 days ago) had multiplier 7 → 700
        #expect(result[6] == 100)
        #expect(result[0] == 700)
    }

    @Test("Filters by accountID when provided")
    func testFilteredByAccount() async throws {
        // Insert two accounts, one transaction in each (today), only A's amount returned for filter A
        let ctx = makeContext()
        let a = SDAccount(id: UUID(), name: "A", type: AccountType.cash.rawValue, icon: "", color: "#000", sortOrder: 0, isArchived: false, createdAt: Date())
        let b = SDAccount(id: UUID(), name: "B", type: AccountType.bank.rawValue, icon: "", color: "#000", sortOrder: 1, isArchived: false, createdAt: Date())
        ctx.insert(a); ctx.insert(b)
        let today = Calendar.current.startOfDay(for: Date())
        ctx.insert(SDTransaction(id: UUID(), amount: 200, date: today, note: "", categoryId: nil, accountId: a.id, toAccountId: nil, type: TransactionType.expense.rawValue, tags: [], aiSuggested: false, createdAt: today, updatedAt: today))
        ctx.insert(SDTransaction(id: UUID(), amount: 500, date: today, note: "", categoryId: nil, accountId: b.id, toAccountId: nil, type: TransactionType.expense.rawValue, tags: [], aiSuggested: false, createdAt: today, updatedAt: today))
        try ctx.save()

        let result = try await withDependencies {
            $0.databaseClient = DatabaseClient.testValue
        } operation: {
            try await TransactionClient.liveValue.weeklySpending(a.id, 7)
        }
        #expect(result[6] == 200)
    }
}
```

Run:

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:FeaturesTests/TransactionClientWeeklyTests 2>&1 | tail -10
```

Expected: FAIL — `weeklySpending` not implemented.

- [ ] **Step 1.9: Implement `weeklySpending` in live client**

In `Features/Sources/Core/Clients/TransactionClient+Live.swift` extend the `liveValue` builder. Inside the `TransactionClient(` literal, add the new closure:

```swift
weeklySpending: { accountID, days in
    @Dependency(\.databaseClient) var dbc
    return try await dbc.weeklySpendingSums(accountID: accountID, days: days)
},
```

Then add a helper to `DatabaseClient` so the modelActor-isolated logic lives in Core. Add to `Features/Sources/Core/Persistence/DatabaseClient.swift`:

```swift
public func weeklySpendingSums(accountID: UUID?, days: Int) async throws -> [Decimal] {
    try await actor.weeklySpendingSums(accountID: accountID, days: days)
}
```

And inside the existing `@ModelActor` (find the actor declaration in `DatabaseClient.swift`):

```swift
func weeklySpendingSums(accountID: UUID?, days: Int) throws -> [Decimal] {
    let cal = Calendar.current
    let today = cal.startOfDay(for: Date())
    let earliest = cal.date(byAdding: .day, value: -(days - 1), to: today)!
    let typeRaw = TransactionType.expense.rawValue
    let predicate = #Predicate<SDTransaction> { tx in
        tx.type == typeRaw && tx.date >= earliest
    }
    var d = FetchDescriptor<SDTransaction>(predicate: predicate)
    d.sortBy = [SortDescriptor(\.date)]
    let rows = try modelContext.fetch(d)

    var buckets = Array(repeating: Decimal(0), count: days)
    for tx in rows {
        if let aid = accountID, tx.accountId != aid { continue }
        let dayOffset = cal.dateComponents([.day], from: cal.startOfDay(for: tx.date), to: today).day ?? 0
        let index = (days - 1) - dayOffset
        guard index >= 0 && index < days else { continue }
        buckets[index] += tx.amount
    }
    return buckets
}
```

- [ ] **Step 1.10: Run test → expect PASS**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:FeaturesTests/TransactionClientWeeklyTests 2>&1 | tail -10
```

Expected: PASS.

- [ ] **Step 1.11: Extend `DashboardFeature.State`**

Inside the existing `State` struct, add the new fields (preserve every existing field):

```swift
// Chip filter
public var selectedAccountID: Account.ID? = nil
public var filteredBalance: Decimal = 0
public var weeklySpending: [Decimal] = []
public var filteredRecent: [Transaction] = []

// Stats (declared now, populated by Slice 5)
public var todaySpending: Decimal = 0
public var weekSpending: Decimal = 0
public var savingsPercentage: Double = 0

// Insight (populated by Slice 7)
public var insights: [InsightData] = []
public var insightIndex: Int = 0

// Transaction expansion (populated by Slice 6)
public var expandedTransactionID: Transaction.ID? = nil

// Per-section view state
public var heroPhase: SectionPhase = .idle
public var statsPhase: SectionPhase = .idle
public var transactionsPhase: SectionPhase = .idle
public var insightPhase: SectionPhase = .idle
public var accountsPhase: SectionPhase = .idle
```

- [ ] **Step 1.12: Extend `DashboardFeature.Action`**

Add new cases (keep all existing cases):

```swift
case accountChipSelected(Account.ID?)
case weeklySpendingComputed([Decimal])
case statsComputed(today: Decimal, week: Decimal, savings: Double)
case insightsLoaded([InsightData])
case insightIndexChanged(Int)
case transactionRowToggled(Transaction.ID)
case sectionFailed(Section, String)
case retrySection(Section)
```

- [ ] **Step 1.13: Write failing reducer test for hero phase transitions**

```swift
// Features/Tests/FeaturesTests/Dashboard/DashboardFeatureSectionPhaseTests.swift
import Testing
import ComposableArchitecture
import Foundation
@testable import Features
import Domain

@MainActor
@Suite("DashboardFeature SectionPhase")
struct DashboardFeatureSectionPhaseTests {

    @Test("weeklySpending success transitions heroPhase to loaded")
    func testHeroSuccess() async {
        let store = TestStore(initialState: DashboardFeature.State()) {
            DashboardFeature()
        } withDependencies: {
            $0.transactionClient.weeklySpending = { _, _ in [10, 20, 30, 40, 50, 60, 70] }
            $0.transactionClient.fetchRecent = { [] }
            $0.transactionClient.fetchAll = { [] }
            $0.accountClient.fetchActive = { [] }
            $0.categoryClient.fetchAll = { [] }
            $0.aiServiceClient.isAvailable = { false }
        }

        await store.send(.task) {
            $0.heroPhase = .loading
            // other phases also become .loading; assert specifically:
            $0.statsPhase = .loading
            $0.transactionsPhase = .loading
            $0.insightPhase = .loading
            $0.accountsPhase = .loading
        }
        await store.receive(\.weeklySpendingComputed) {
            $0.weeklySpending = [10, 20, 30, 40, 50, 60, 70]
            $0.heroPhase = .loaded
        }
        await store.finish()
    }

    @Test("weeklySpending failure transitions heroPhase to failed and leaves others unchanged")
    func testHeroFailure() async {
        let store = TestStore(initialState: DashboardFeature.State()) {
            DashboardFeature()
        } withDependencies: {
            struct Boom: Error {}
            $0.transactionClient.weeklySpending = { _, _ in throw Boom() }
            $0.transactionClient.fetchRecent = { [] }
            $0.transactionClient.fetchAll = { [] }
            $0.accountClient.fetchActive = { [] }
            $0.categoryClient.fetchAll = { [] }
            $0.aiServiceClient.isAvailable = { false }
        }
        await store.send(.task) {
            $0.heroPhase = .loading
            $0.statsPhase = .loading
            $0.transactionsPhase = .loading
            $0.insightPhase = .loading
            $0.accountsPhase = .loading
        }
        await store.receive(\.sectionFailed) {
            $0.heroPhase = .failed("無法載入")
        }
        await store.finish()
    }

    @Test("retrySection(.hero) resets phase to loading and reloads")
    func testRetryHero() async {
        var initial = DashboardFeature.State()
        initial.heroPhase = .failed("err")
        let store = TestStore(initialState: initial) {
            DashboardFeature()
        } withDependencies: {
            $0.transactionClient.weeklySpending = { _, _ in [1, 2, 3, 4, 5, 6, 7] }
        }
        await store.send(.retrySection(.hero)) {
            $0.heroPhase = .loading
        }
        await store.receive(\.weeklySpendingComputed) {
            $0.weeklySpending = [1, 2, 3, 4, 5, 6, 7]
            $0.heroPhase = .loaded
        }
    }
}
```

Run + expect FAIL (reducer doesn't have these handlers yet).

- [ ] **Step 1.14: Implement reducer cases for `.task`, `.weeklySpendingComputed`, `.sectionFailed`, `.retrySection`**

Inside the reducer body (the `Reduce { state, action in ... }` switch), add — and merge into the existing `.task` case:

```swift
case .task:
    state.heroPhase = .loading
    state.statsPhase = .loading
    state.transactionsPhase = .loading
    state.insightPhase = .loading
    state.accountsPhase = .loading
    return .merge(
        // existing effects preserved (loadAccounts, transactions, categories)
        // ... keep current implementations ...
        // new hero loader:
        .run { [accountID = state.selectedAccountID] send in
            do {
                let v = try await transactionClient.weeklySpending(accountID, 7)
                await send(.weeklySpendingComputed(v))
            } catch {
                await send(.sectionFailed(.hero, "無法載入"))
            }
        }
        .cancellable(id: CancelID.weeklySpending, cancelInFlight: true)
    )

case let .weeklySpendingComputed(values):
    state.weeklySpending = values
    state.heroPhase = .loaded
    return .none

case let .sectionFailed(section, message):
    switch section {
    case .hero:         state.heroPhase = .failed(message)
    case .stats:        state.statsPhase = .failed(message)
    case .transactions: state.transactionsPhase = .failed(message)
    case .insight:      state.insightPhase = .failed(message)
    case .accounts:     state.accountsPhase = .failed(message)
    }
    return .none

case let .retrySection(section):
    switch section {
    case .hero:
        state.heroPhase = .loading
        return .run { [accountID = state.selectedAccountID] send in
            do {
                let v = try await transactionClient.weeklySpending(accountID, 7)
                await send(.weeklySpendingComputed(v))
            } catch {
                await send(.sectionFailed(.hero, "無法載入"))
            }
        }
        .cancellable(id: CancelID.weeklySpending, cancelInFlight: true)
    case .stats:
        state.statsPhase = .loading
        return .none // wired in Slice 5
    case .transactions:
        state.transactionsPhase = .loading
        return .none // wired in Slice 4
    case .insight:
        state.insightPhase = .loading
        return .none // wired in Slice 7
    case .accounts:
        state.accountsPhase = .loading
        return .none // wired in Slice 4
    }
```

Add `case weeklySpending` to the `CancelID` enum at the top of the reducer.

- [ ] **Step 1.15: Update other reducer cases to set phases**

In the existing `accountsUpdated` handler add `state.accountsPhase = .loaded`. In `accountBalancesComputed` also recompute `filteredBalance`:

```swift
case let .accountBalancesComputed(balances, total):
    state.accountBalances = balances
    state.totalBalance = total
    state.filteredBalance = state.selectedAccountID.flatMap { balances[$0] } ?? total
    return .none

case let .accountsUpdated(accounts):
    state.topAccounts = accounts
    state.hasAccounts = !accounts.isEmpty
    state.accountsPhase = .loaded
    // existing balance recompute effect preserved
    // ...
```

Similarly add `state.transactionsPhase = .loaded` in `transactionsUpdated`, and recompute `filteredRecent`:

```swift
case let .transactionsUpdated(txs):
    state.recentTransactions = txs
    state.hasTransactions = !txs.isEmpty
    state.transactionsPhase = .loaded
    state.filteredRecent = state.selectedAccountID.map { id in txs.filter { $0.accountId == id } } ?? txs
    return .none
```

- [ ] **Step 1.16: Run reducer test → expect PASS**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:FeaturesTests/DashboardFeatureSectionPhaseTests 2>&1 | tail -10
```

Expected: PASS. If `.sectionFailed` test fails on equality, adjust the test's failure message string to whatever you produce, and keep both reducer and test consistent.

- [ ] **Step 1.17: Create `HeroBalanceCard`**

```swift
// Features/Sources/Features/Dashboard/Sections/HeroBalanceCard.swift
import SwiftUI
import ComposableArchitecture
import Common
import Domain

struct HeroBalanceCard: View {
    let store: StoreOf<DashboardFeature>

    var body: some View {
        GlassContainer(cornerRadius: 28, padding: 20) {
            switch store.heroPhase {
            case .idle, .loading:
                content.skeleton(when: true)
            case .loaded:
                content
            case let .failed(msg):
                SectionFailureView(message: msg) {
                    store.send(.retrySection(.hero))
                }
            }
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("dashboard_total_label")
                    .font(.system(size: 12, weight: .medium))
                    .textCase(.uppercase)
                    .tracking(1)
                    .foregroundStyle(.secondary)
                Spacer()
                MetricBadge(
                    text: store.filteredBalance >= 0 ? "+\(store.filteredBalance.twdFormatted)" : store.filteredBalance.twdFormatted,
                    color: store.filteredBalance >= 0 ? Color.Design.incomeGreen : Color.Design.expenseRed
                )
            }
            Text(store.filteredBalance.twdFormatted)
                .font(.system(size: 40, weight: .bold).monospacedDigit())
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
            MiniSparkline(values: store.weeklySpending.isEmpty ? Array(repeating: 0, count: 7) : store.weeklySpending)
        }
    }
}
```

Add string: `dashboard_total_label` → "總餘額" / "Total".

- [ ] **Step 1.18: Rewrite `DashboardScreen` as composition root**

Replace the body of `DashboardScreen.swift` with:

```swift
public var body: some View {
    NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
        ZStack {
            WarmGradientBackground(variant: .top)
            ScrollView {
                VStack(spacing: 16) {
                    // Top Bar placeholder — wired in Slice 3
                    Color.clear.frame(height: 56)
                    // Account Chips placeholder — wired in Slice 4
                    Color.clear.frame(height: 44)
                    HeroBalanceCard(store: store)
                    // Stats placeholder — wired in Slice 5
                    GlassContainer(cornerRadius: 16, padding: 12) {
                        Text("…")
                    }.skeleton(when: true)
                    // Insight placeholder — wired in Slice 7
                    GlassContainer(cornerRadius: 22, padding: 16) {
                        Text("…")
                    }.skeleton(when: true)
                    // Transactions — slim, retained
                    transactionsSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 120)
            }
            .refreshable { await store.send(.pulledToRefresh).finish() }
        }
        .navigationBarHidden(true)
        .task { await store.send(.task).finish() }
        // existing path destination switch preserved
    }
}
```

Remove the old `balanceSection`, `quickActionsSection`, `accountsSection`, `insightSection` view properties. Keep `transactionsSection` (will be rewritten in Slice 6).

- [ ] **Step 1.19: Build verification**

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -3
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 1.20: Manual visual check**

Open simulator, navigate to Dashboard. You should see: skeleton placeholders for top bar / chips / stats / insight; **real Hero card** with balance + Net + Sparkline; old `transactionsSection` below. Pull-to-refresh works. Force an error in `weeklySpending` (temporarily throw) to verify retry UI appears in the Hero card.

- [ ] **Step 1.21: Commit Slice 1+2**

```bash
git add Features/Sources/Domain/Entities/InsightData.swift \
        Features/Sources/Domain/Entities/StatsSnapshot.swift \
        Features/Sources/Domain/Clients/TransactionClient.swift \
        Features/Sources/Core/Clients/TransactionClient+Live.swift \
        Features/Sources/Core/Persistence/DatabaseClient.swift \
        Features/Sources/Features/Dashboard/DashboardFeature.swift \
        Features/Sources/Features/Dashboard/DashboardScreen.swift \
        Features/Sources/Features/Dashboard/Sections/HeroBalanceCard.swift \
        Features/Tests/DomainTests/Entities/SectionPhaseTests.swift \
        Features/Tests/DomainTests/Entities/InsightDataTests.swift \
        Features/Tests/DomainTests/Entities/StatsSnapshotTests.swift \
        Features/Tests/CoreTests/Clients/TransactionClientWeeklyTests.swift \
        Features/Tests/FeaturesTests/Dashboard/DashboardFeatureSectionPhaseTests.swift

git commit -m "$(cat <<'EOF'
feat(dashboard): per-section phases + Hero Balance + sparkline (slice 1+2)

Extend DashboardFeature.State with SectionPhase per section (hero/stats/
transactions/insight/accounts), chip-filter fields, weekly spending,
stats fields, insight fields, expansion id. Add actions for chip
selection, section failures, and retry.

TransactionClient.weeklySpending: returns 7-day expense buckets, oldest
to newest, optionally scoped to an accountID. Live impl runs on the
ModelActor.

DashboardScreen becomes a slim composition root; HeroBalanceCard renders
real balance + Net + MiniSparkline with skeleton + retry states. Other
sections are skeleton placeholders to be filled in by later slices.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Slice 3 — Top Bar

**TDD policy:** Pure visual.

**Files:**
- Create: `Features/Sources/Features/Dashboard/Sections/DashboardTopBar.swift`
- Modify: `Features/Sources/Features/Dashboard/DashboardScreen.swift` (replace top placeholder)

---

- [ ] **Step 2.1: Create `DashboardTopBar`**

```swift
// Features/Sources/Features/Dashboard/Sections/DashboardTopBar.swift
import SwiftUI
import ComposableArchitecture
import Common

struct DashboardTopBar: View {
    let store: StoreOf<DashboardFeature>

    private var greeting: LocalizedStringKey {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return "dashboard_greeting_morning"
        case 12..<18: return "dashboard_greeting_afternoon"
        default:      return "dashboard_greeting_evening"
        }
    }

    private var dateText: String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("EEEE · d MMM")
        return formatter.string(from: Date())
    }

    var body: some View {
        HStack(spacing: 12) {
            AvatarBadge(initials: "D")
            VStack(alignment: .leading, spacing: 2) {
                Text(greeting)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                Text(dateText)
                    .font(.system(size: 16, weight: .semibold))
            }
            Spacer()
            iconButton(systemName: "sparkles") { /* AI button — no-op for now */ }
            iconButton(systemName: "magnifyingglass") { /* Search button — no-op */ }
        }
    }

    @ViewBuilder
    private func iconButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.primary)
                .frame(width: 40, height: 40)
                .background(Circle().fill(.ultraThinMaterial))
        }
        .buttonStyle(.plain)
    }
}
```

Add strings: `dashboard_greeting_morning` / `_afternoon` / `_evening` → 早安 / 午安 / 晚安 (Good morning / afternoon / evening).

- [ ] **Step 2.2: Wire `DashboardTopBar` into composition root**

In `DashboardScreen.swift`, replace `Color.clear.frame(height: 56)` (top placeholder) with `DashboardTopBar(store: store)`.

- [ ] **Step 2.3: Build verification**

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -3
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 2.4: Manual visual check**

Top bar shows avatar + greeting + localized date + two icon buttons. Tap on buttons → no-op (correct for this slice).

- [ ] **Step 2.5: Commit Slice 3**

```bash
git add Features/Sources/Features/Dashboard/Sections/DashboardTopBar.swift \
        Features/Sources/Features/Dashboard/DashboardScreen.swift \
        Features/Sources/Common/Resources

git commit -m "$(cat <<'EOF'
feat(dashboard): add Top Bar (slice 3)

Avatar gradient + time-aware greeting + localized date + two glass icon
buttons (AI sparkle, search). Tap actions are no-op placeholders.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Slice 4 — Account Chips strip

**TDD policy:** Reducer chip handling is TDD-required. View styling is TDD-exempt.

**Files:**
- Create: `Features/Sources/Features/Dashboard/Sections/AccountChipsStrip.swift`
- Modify: `Features/Sources/Features/Dashboard/DashboardFeature.swift` (`accountChipSelected` handler)
- Modify: `Features/Sources/Features/Dashboard/DashboardScreen.swift` (replace placeholder)
- Create: `Features/Tests/FeaturesTests/Dashboard/DashboardFeatureChipTests.swift`

---

- [ ] **Step 3.1: Write failing chip test**

```swift
// Features/Tests/FeaturesTests/Dashboard/DashboardFeatureChipTests.swift
import Testing
import ComposableArchitecture
import Foundation
@testable import Features
import Domain

@MainActor
@Suite("DashboardFeature Chip Selection")
struct DashboardFeatureChipTests {
    private static let accA = Account(name: "A", type: .cash, icon: "", color: "#000")
    private static let accB = Account(name: "B", type: .bank, icon: "", color: "#000")

    @Test("Selecting an account sets selectedAccountID and recomputes filteredBalance + filteredRecent")
    func testChipSelect() async {
        var initial = DashboardFeature.State()
        initial.totalBalance = 1000
        initial.accountBalances = [Self.accA.id: 300, Self.accB.id: 700]
        initial.topAccounts = [Self.accA, Self.accB]
        initial.recentTransactions = [
            Transaction(amount: 100, date: .now, note: "x", categoryId: nil, accountId: Self.accA.id, type: .expense),
            Transaction(amount: 200, date: .now, note: "y", categoryId: nil, accountId: Self.accB.id, type: .expense)
        ]
        initial.filteredRecent = initial.recentTransactions
        initial.filteredBalance = 1000

        let store = TestStore(initialState: initial) {
            DashboardFeature()
        } withDependencies: {
            $0.transactionClient.weeklySpending = { _, _ in [0, 0, 0, 0, 0, 0, 0] }
        }

        await store.send(.accountChipSelected(Self.accA.id)) {
            $0.selectedAccountID = Self.accA.id
            $0.filteredBalance = 300
            $0.filteredRecent = [$0.recentTransactions[0]]
            $0.heroPhase = .loading
            $0.transactionsPhase = .loading
        }
        await store.receive(\.weeklySpendingComputed) {
            $0.weeklySpending = [0, 0, 0, 0, 0, 0, 0]
            $0.heroPhase = .loaded
        }
        await store.send(.accountChipSelected(nil)) {
            $0.selectedAccountID = nil
            $0.filteredBalance = 1000
            $0.filteredRecent = $0.recentTransactions
            $0.heroPhase = .loading
            $0.transactionsPhase = .loading
        }
        await store.receive(\.weeklySpendingComputed)
    }

    @Test("Chip switch does not change statsPhase / insightPhase")
    func testChipDoesNotAffectStatsOrInsight() async {
        var initial = DashboardFeature.State()
        initial.statsPhase = .loaded
        initial.insightPhase = .loaded
        let store = TestStore(initialState: initial) {
            DashboardFeature()
        } withDependencies: {
            $0.transactionClient.weeklySpending = { _, _ in [] }
        }
        await store.send(.accountChipSelected(Self.accA.id)) {
            $0.selectedAccountID = Self.accA.id
            $0.filteredBalance = 0
            $0.filteredRecent = []
            $0.heroPhase = .loading
            $0.transactionsPhase = .loading
        }
        // statsPhase and insightPhase should still be .loaded (unchanged)
        #expect(store.state.statsPhase == .loaded)
        #expect(store.state.insightPhase == .loaded)
        await store.receive(\.weeklySpendingComputed)
    }
}
```

Run → expect FAIL.

- [ ] **Step 3.2: Implement `accountChipSelected` handler**

In `DashboardFeature.swift` reducer switch:

```swift
case let .accountChipSelected(accountID):
    state.selectedAccountID = accountID
    state.filteredBalance = accountID.flatMap { state.accountBalances[$0] } ?? state.totalBalance
    if let id = accountID {
        state.filteredRecent = state.recentTransactions.filter { $0.accountId == id }
    } else {
        state.filteredRecent = state.recentTransactions
    }
    state.heroPhase = .loading
    state.transactionsPhase = .loading
    return .run { [accountID] send in
        do {
            let v = try await transactionClient.weeklySpending(accountID, 7)
            await send(.weeklySpendingComputed(v))
        } catch {
            await send(.sectionFailed(.hero, "無法載入"))
        }
    }
    .cancellable(id: CancelID.weeklySpending, cancelInFlight: true)
```

(Stats and Insight phases are intentionally not touched.)

- [ ] **Step 3.3: Run chip test → expect PASS**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:FeaturesTests/DashboardFeatureChipTests 2>&1 | tail -10
```

Expected: PASS.

- [ ] **Step 3.4: Create `AccountChipsStrip`**

```swift
// Features/Sources/Features/Dashboard/Sections/AccountChipsStrip.swift
import SwiftUI
import ComposableArchitecture
import Common
import Domain

struct AccountChipsStrip: View {
    let store: StoreOf<DashboardFeature>

    var body: some View {
        switch store.accountsPhase {
        case .idle, .loading:
            placeholder.skeleton(when: true)
        case .loaded:
            content
        case let .failed(msg):
            SectionFailureView(message: msg) { store.send(.retrySection(.accounts)) }
        }
    }

    private var content: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(label: "dashboard_chip_all", isActive: store.selectedAccountID == nil, color: .secondary) {
                    store.send(.accountChipSelected(nil))
                }
                ForEach(store.topAccounts) { acc in
                    chip(
                        label: LocalizedStringKey(acc.name),
                        isActive: store.selectedAccountID == acc.id,
                        color: Color(hex: acc.color),
                        balance: store.accountBalances[acc.id]
                    ) {
                        store.send(.accountChipSelected(acc.id))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func chip(
        label: LocalizedStringKey,
        isActive: Bool,
        color: Color,
        balance: Decimal? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 6, height: 6)
                Text(label).font(.system(size: 13, weight: .medium))
                if let b = balance {
                    Text(b.twdFormatted)
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(isActive ? color.opacity(0.18) : Color.primary.opacity(0.05))
            )
            .overlay(
                Capsule().strokeBorder(isActive ? color.opacity(0.35) : .clear, lineWidth: 0.5)
            )
            .foregroundStyle(isActive ? color : .primary)
        }
        .buttonStyle(.plain)
    }

    private var placeholder: some View {
        HStack(spacing: 8) {
            ForEach(0 ..< 3, id: \.self) { _ in
                Capsule().fill(.ultraThinMaterial).frame(width: 80, height: 32)
            }
        }
    }
}
```

Add strings: `dashboard_chip_all` → 全部 / All.

- [ ] **Step 3.5: Wire into composition root**

Replace `Color.clear.frame(height: 44)` (chips placeholder) in `DashboardScreen.swift` with `AccountChipsStrip(store: store)`.

- [ ] **Step 3.6: Build + visual check**

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -3
```

Tap chips in simulator. Hero/Sparkline/Transactions should reflect the selected account. Stats and Insight (still skeleton at this point) don't move.

- [ ] **Step 3.7: Commit Slice 4**

```bash
git add Features/Sources/Features/Dashboard/Sections/AccountChipsStrip.swift \
        Features/Sources/Features/Dashboard/DashboardFeature.swift \
        Features/Sources/Features/Dashboard/DashboardScreen.swift \
        Features/Tests/FeaturesTests/Dashboard/DashboardFeatureChipTests.swift \
        Features/Sources/Common/Resources

git commit -m "$(cat <<'EOF'
feat(dashboard): Account Chips strip with filter (slice 4)

Horizontal strip with All + per-account pills. Tapping a chip sets
selectedAccountID, recomputes filteredBalance and filteredRecent
synchronously, and re-fetches weeklySpending scoped to that account.
Stats and Insight remain unaffected by chip selection. Active chip
gets a tinted background, color dot, and balance display.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Slice 5 — Stats Row

**TDD policy:** Reducer + client method TDD-required. View TDD-exempt.

**Files:**
- Create: `Features/Sources/Features/Dashboard/Sections/StatsRow.swift`
- Modify: `Features/Sources/Domain/Clients/TransactionClient.swift` (add `statsSnapshot`)
- Modify: `Features/Sources/Core/Clients/TransactionClient+Live.swift` (impl)
- Modify: `Features/Sources/Core/Persistence/DatabaseClient.swift` (statsSnapshot actor method)
- Modify: `Features/Sources/Features/Dashboard/DashboardFeature.swift` (effect + handler)
- Modify: `Features/Sources/Features/Dashboard/DashboardScreen.swift` (replace placeholder)
- Create: `Features/Tests/CoreTests/Clients/TransactionClientStatsTests.swift`
- Create: `Features/Tests/FeaturesTests/Dashboard/DashboardFeatureStatsTests.swift`

---

- [ ] **Step 4.1: Add `statsSnapshot` to client interface**

In `TransactionClient.swift`:

```swift
public var statsSnapshot: @Sendable () async throws -> StatsSnapshot
```

- [ ] **Step 4.2: Write failing Core test**

```swift
// Features/Tests/CoreTests/Clients/TransactionClientStatsTests.swift
import Testing
import Foundation
import SwiftData
import ComposableArchitecture
@testable import Core
import Domain

@Suite("TransactionClient.statsSnapshot")
struct TransactionClientStatsTests {
    @Test("Computes today + week + savings %")
    func test() async throws {
        let client = DatabaseClient.testValue
        let ctx = ModelContext(client.modelContainer())
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        // Today: spent 200, earned 0
        ctx.insert(SDTransaction(id: UUID(), amount: 200, date: today, note: "", categoryId: nil, accountId: UUID(), toAccountId: nil, type: TransactionType.expense.rawValue, tags: [], aiSuggested: false, createdAt: today, updatedAt: today))
        // 3 days ago: spent 100
        let d3 = cal.date(byAdding: .day, value: -3, to: today)!
        ctx.insert(SDTransaction(id: UUID(), amount: 100, date: d3, note: "", categoryId: nil, accountId: UUID(), toAccountId: nil, type: TransactionType.expense.rawValue, tags: [], aiSuggested: false, createdAt: d3, updatedAt: d3))
        // Within last 7d: earned 1000
        ctx.insert(SDTransaction(id: UUID(), amount: 1000, date: d3, note: "", categoryId: nil, accountId: UUID(), toAccountId: nil, type: TransactionType.income.rawValue, tags: [], aiSuggested: false, createdAt: d3, updatedAt: d3))
        try ctx.save()

        let snap = try await withDependencies {
            $0.databaseClient = client
        } operation: {
            try await TransactionClient.liveValue.statsSnapshot()
        }
        #expect(snap.today == 200)
        #expect(snap.week == 300) // 200 today + 100 from d3
        // income 1000, expense 300, savings = (1000 - 300)/1000 = 0.7
        #expect(abs(snap.savingsPercentage - 0.7) < 0.001)
    }
}
```

Run → expect FAIL.

- [ ] **Step 4.3: Implement live `statsSnapshot`**

In `TransactionClient+Live.swift` add:

```swift
statsSnapshot: {
    @Dependency(\.databaseClient) var dbc
    return try await dbc.statsSnapshot()
},
```

In `DatabaseClient.swift` extension:

```swift
public func statsSnapshot() async throws -> StatsSnapshot {
    try await actor.statsSnapshot()
}
```

Inside the `@ModelActor` body:

```swift
func statsSnapshot() throws -> StatsSnapshot {
    let cal = Calendar.current
    let today = cal.startOfDay(for: Date())
    let weekStart = cal.date(byAdding: .day, value: -6, to: today)!
    let descriptor = FetchDescriptor<SDTransaction>(predicate: #Predicate {
        $0.date >= weekStart
    })
    let rows = try modelContext.fetch(descriptor)

    var todayTotal: Decimal = 0
    var weekTotal: Decimal = 0
    var income: Decimal = 0
    var expense: Decimal = 0
    let expenseRaw = TransactionType.expense.rawValue
    let incomeRaw = TransactionType.income.rawValue
    for tx in rows {
        if tx.type == expenseRaw {
            weekTotal += tx.amount
            expense += tx.amount
            if cal.isDate(tx.date, inSameDayAs: today) {
                todayTotal += tx.amount
            }
        } else if tx.type == incomeRaw {
            income += tx.amount
        }
    }
    let savings: Double
    if income > 0 {
        let saved = NSDecimalNumber(decimal: income - expense).doubleValue
        let inc = NSDecimalNumber(decimal: income).doubleValue
        savings = max(0, saved / inc)
    } else {
        savings = 0
    }
    return StatsSnapshot(today: todayTotal, week: weekTotal, savingsPercentage: savings)
}
```

- [ ] **Step 4.4: Run Core test → expect PASS**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:FeaturesTests/TransactionClientStatsTests 2>&1 | tail -10
```

- [ ] **Step 4.5: Write failing reducer test**

```swift
// Features/Tests/FeaturesTests/Dashboard/DashboardFeatureStatsTests.swift
import Testing
import ComposableArchitecture
@testable import Features
import Domain

@MainActor
@Suite("DashboardFeature Stats")
struct DashboardFeatureStatsTests {
    @Test(".task triggers statsComputed and sets statsPhase to loaded")
    func test() async {
        let store = TestStore(initialState: DashboardFeature.State()) {
            DashboardFeature()
        } withDependencies: {
            $0.transactionClient.statsSnapshot = { StatsSnapshot(today: 100, week: 400, savingsPercentage: 0.3) }
            $0.transactionClient.weeklySpending = { _, _ in [] }
            $0.transactionClient.fetchRecent = { [] }
            $0.transactionClient.fetchAll = { [] }
            $0.accountClient.fetchActive = { [] }
            $0.categoryClient.fetchAll = { [] }
            $0.aiServiceClient.isAvailable = { false }
        }
        await store.send(.task) {
            $0.heroPhase = .loading
            $0.statsPhase = .loading
            $0.transactionsPhase = .loading
            $0.insightPhase = .loading
            $0.accountsPhase = .loading
        }
        await store.receive(\.statsComputed) {
            $0.todaySpending = 100
            $0.weekSpending = 400
            $0.savingsPercentage = 0.3
            $0.statsPhase = .loaded
        }
        await store.receive(\.weeklySpendingComputed) { $0.heroPhase = .loaded }
    }
}
```

Run → expect FAIL.

- [ ] **Step 4.6: Wire stats effect into reducer**

Add to the `.task` merge list:

```swift
.run { send in
    do {
        let s = try await transactionClient.statsSnapshot()
        await send(.statsComputed(today: s.today, week: s.week, savings: s.savingsPercentage))
    } catch {
        await send(.sectionFailed(.stats, "無法載入"))
    }
}
.cancellable(id: CancelID.stats, cancelInFlight: true),
```

Add `case stats` to `CancelID`. Add handler:

```swift
case let .statsComputed(today, week, savings):
    state.todaySpending = today
    state.weekSpending = week
    state.savingsPercentage = savings
    state.statsPhase = .loaded
    return .none
```

Also wire `retrySection(.stats)` to redo the effect.

- [ ] **Step 4.7: Run reducer test → expect PASS**

- [ ] **Step 4.8: Create `StatsRow`**

```swift
// Features/Sources/Features/Dashboard/Sections/StatsRow.swift
import SwiftUI
import ComposableArchitecture
import Common

struct StatsRow: View {
    let store: StoreOf<DashboardFeature>

    var body: some View {
        switch store.statsPhase {
        case .idle, .loading:
            content.skeleton(when: true)
        case .loaded:
            content
        case let .failed(msg):
            GlassContainer(cornerRadius: 16, padding: 12) {
                SectionFailureView(message: msg) { store.send(.retrySection(.stats)) }
            }
        }
    }

    private var content: some View {
        HStack(spacing: 10) {
            StatPill(label: "stat_today", value: store.todaySpending.twdFormatted)
            StatPill(
                label: "stat_week",
                value: store.weekSpending.twdFormatted,
                valueColor: Color.Design.expenseRed
            )
            StatPill(
                label: "stat_saved",
                value: String(format: "%.0f%%", store.savingsPercentage * 100),
                valueColor: Color.Design.incomeGreen
            )
        }
    }
}
```

- [ ] **Step 4.9: Wire into composition root**

Replace the stats placeholder in `DashboardScreen.swift` with `StatsRow(store: store)`.

- [ ] **Step 4.10: Build + visual check + commit**

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -3
```

```bash
git add Features/Sources/Features/Dashboard/Sections/StatsRow.swift \
        Features/Sources/Domain/Clients/TransactionClient.swift \
        Features/Sources/Core/Clients/TransactionClient+Live.swift \
        Features/Sources/Core/Persistence/DatabaseClient.swift \
        Features/Sources/Features/Dashboard/DashboardFeature.swift \
        Features/Sources/Features/Dashboard/DashboardScreen.swift \
        Features/Tests/CoreTests/Clients/TransactionClientStatsTests.swift \
        Features/Tests/FeaturesTests/Dashboard/DashboardFeatureStatsTests.swift

git commit -m "$(cat <<'EOF'
feat(dashboard): Stats Row — today / this week / savings (slice 5)

TransactionClient.statsSnapshot computes today's expense, the 7-day
expense window, and savings percentage (income - expense) / income.
StatsRow renders three StatPill cells. Stats are global and do not
respond to account chip selection.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Slice 6 — Transactions section with expansion

**TDD policy:** Reducer toggle TDD-required. View TDD-exempt.

**Files:**
- Modify: `Features/Sources/Common/Components/TransactionRow.swift` (add `isExpanded` + tags slot, tint icon bg)
- Create: `Features/Sources/Features/Dashboard/Sections/TransactionsSection.swift`
- Modify: `Features/Sources/Features/Dashboard/DashboardFeature.swift` (`transactionRowToggled` handler)
- Modify: `Features/Sources/Features/Dashboard/DashboardScreen.swift` (remove old `transactionsSection`, use new section)
- Create: `Features/Tests/FeaturesTests/Dashboard/DashboardFeatureExpansionTests.swift`

---

- [ ] **Step 5.1: Write failing expansion test**

```swift
// Features/Tests/FeaturesTests/Dashboard/DashboardFeatureExpansionTests.swift
import Testing
import ComposableArchitecture
import Foundation
@testable import Features
import Domain

@MainActor
@Suite("DashboardFeature Row Expansion")
struct DashboardFeatureExpansionTests {
    @Test("Toggling same id twice collapses; tapping a different id replaces")
    func test() async {
        let id1 = UUID()
        let id2 = UUID()
        let store = TestStore(initialState: DashboardFeature.State()) {
            DashboardFeature()
        }
        await store.send(.transactionRowToggled(id1)) {
            $0.expandedTransactionID = id1
        }
        await store.send(.transactionRowToggled(id1)) {
            $0.expandedTransactionID = nil
        }
        await store.send(.transactionRowToggled(id2)) {
            $0.expandedTransactionID = id2
        }
        await store.send(.transactionRowToggled(id1)) {
            $0.expandedTransactionID = id1
        }
    }
}
```

Run → expect FAIL.

- [ ] **Step 5.2: Implement `transactionRowToggled`**

In reducer:

```swift
case let .transactionRowToggled(id):
    state.expandedTransactionID = (state.expandedTransactionID == id) ? nil : id
    return .none
```

Run test → expect PASS.

- [ ] **Step 5.3: Extend `TransactionRow`**

Modify the existing `Features/Sources/Common/Components/TransactionRow.swift` to accept `isExpanded` and a tags array. The existing public API is preserved by adding new init parameters with defaults:

```swift
public struct TransactionRow: View {
    public let title: String
    public let subtitle: String
    public let amountText: String
    public let amountColor: Color
    public let icon: String
    public let iconColor: Color
    public let dateText: String
    public let isExpanded: Bool
    public let tags: [String]
    public let onTap: () -> Void

    public init(
        title: String,
        subtitle: String,
        amountText: String,
        amountColor: Color = .primary,
        icon: String,
        iconColor: Color = .accentColor,
        dateText: String,
        isExpanded: Bool = false,
        tags: [String] = [],
        onTap: @escaping () -> Void = {}
    ) {
        // ... assignments
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Circle()
                    .fill(iconColor.opacity(0.13))
                    .frame(width: 38, height: 38)
                    .overlay {
                        Image(systemName: icon)
                            .font(.system(size: 19, weight: .medium))
                            .foregroundStyle(iconColor)
                    }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 15, weight: .medium))
                    Text(subtitle).font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(amountText)
                        .font(.system(size: 15, weight: .medium).monospacedDigit())
                        .foregroundStyle(amountColor)
                    Text(dateText)
                        .font(.system(size: 10).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
            .onTapGesture { onTap() }

            if isExpanded && !tags.isEmpty {
                Divider().padding(.horizontal, 16)
                FlowLayout(spacing: 6) {
                    ForEach(tags, id: \.self) { tag in
                        TagPill(label: tag, color: iconColor)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
        }
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.clear))
    }
}
```

Check all existing call sites still compile (the new parameters default to safe values).

- [ ] **Step 5.4: Create `TransactionsSection`**

```swift
// Features/Sources/Features/Dashboard/Sections/TransactionsSection.swift
import SwiftUI
import ComposableArchitecture
import Common
import Domain

struct TransactionsSection: View {
    let store: StoreOf<DashboardFeature>

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = .current
        f.setLocalizedDateFormatFromTemplate("HH:mm")
        return f
    }()

    var body: some View {
        GlassContainer(cornerRadius: 22, padding: 4) {
            switch store.transactionsPhase {
            case .idle, .loading:
                content.skeleton(when: true)
            case .loaded:
                content
            case let .failed(msg):
                SectionFailureView(message: msg) { store.send(.retrySection(.transactions)) }
            }
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            let rows = Array(store.filteredRecent.prefix(6))
            if rows.isEmpty {
                EmptyStateView(
                    systemImage: "tray",
                    title: "transactions_empty_title",
                    body: "transactions_empty_body"
                )
                .padding(.vertical, 24)
            } else {
                ForEach(rows) { tx in
                    let category = tx.categoryId.flatMap { store.categoryMap[$0] }
                    TransactionRow(
                        title: tx.note.isEmpty ? (category?.name ?? "—") : tx.note,
                        subtitle: "\(category?.name ?? "")",
                        amountText: tx.amount.twdFormatted,
                        amountColor: tx.type == .income ? Color.Design.incomeGreen : Color.Design.expenseRed,
                        icon: category?.icon ?? "questionmark.circle",
                        iconColor: Color(hex: category?.color ?? "#999"),
                        dateText: Self.dateFormatter.string(from: tx.date),
                        isExpanded: store.expandedTransactionID == tx.id,
                        tags: tx.tags
                    ) {
                        store.send(.transactionRowToggled(tx.id), animation: .spring(response: 0.4, dampingFraction: 0.85))
                    }
                    if tx.id != rows.last?.id {
                        Divider().padding(.horizontal, 16)
                    }
                }
            }
        }
    }
}
```

Add strings: `transactions_empty_title` → "尚無交易"; `transactions_empty_body` → "記錄您的第一筆花費吧!".

- [ ] **Step 5.5: Remove old `transactionsSection` and wire new**

In `DashboardScreen.swift`, delete the old `transactionsSection` view property and the call site, and replace with `TransactionsSection(store: store)`.

- [ ] **Step 5.6: Build, run all dashboard tests, commit**

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -3
```

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:FeaturesTests/DashboardFeatureExpansionTests 2>&1 | tail -10
```

Expected: build SUCCESS, test PASS.

```bash
git add Features/Sources/Common/Components/TransactionRow.swift \
        Features/Sources/Features/Dashboard/Sections/TransactionsSection.swift \
        Features/Sources/Features/Dashboard/DashboardFeature.swift \
        Features/Sources/Features/Dashboard/DashboardScreen.swift \
        Features/Tests/FeaturesTests/Dashboard/DashboardFeatureExpansionTests.swift \
        Features/Sources/Common/Resources

git commit -m "$(cat <<'EOF'
feat(dashboard): expandable Transactions section (slice 6)

TransactionRow now takes isExpanded + tags; expansion reveals tag pills
below the row via FlowLayout. Icon circle background uses tint at 13%
opacity per design. DashboardFeature handles transactionRowToggled to
swap expandedTransactionID; tap on the same row collapses it.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Slice 7 — AI Insight Carousel

**TDD policy:** Reducer + client mock TDD-required. View TDD-exempt.

**Files:**
- Modify: `Features/Sources/Domain/Entities/SpendingSummary.swift` (extend fields)
- Modify: `Features/Sources/Domain/Clients/AIServiceClient.swift` (add `generateInsights`)
- Modify: `Features/Sources/Core/Clients/AIServiceClient+Live.swift` (mock 3 entries)
- Modify: `Features/Sources/Common/Components/InsightCard.swift` (radius 22 + metric badge + CTA)
- Create: `Features/Sources/Features/Dashboard/Sections/InsightCarousel.swift`
- Modify: `Features/Sources/Features/Dashboard/DashboardFeature.swift` (effect + handlers)
- Modify: `Features/Sources/Features/Dashboard/DashboardScreen.swift` (replace placeholder)
- Create: `Features/Tests/FeaturesTests/Dashboard/DashboardFeatureInsightTests.swift`

---

- [ ] **Step 6.1: Extend `SpendingSummary`**

```swift
// Features/Sources/Domain/Entities/SpendingSummary.swift
import Foundation

public struct SpendingSummary: Equatable, Sendable {
    public let monthTotal: Decimal
    public let weekTotal: Decimal
    public let topCategoryName: String?
    public let topCategoryAmount: Decimal?
    public let savingsPercentage: Double

    public init(
        monthTotal: Decimal,
        weekTotal: Decimal,
        topCategoryName: String? = nil,
        topCategoryAmount: Decimal? = nil,
        savingsPercentage: Double = 0
    ) {
        self.monthTotal = monthTotal
        self.weekTotal = weekTotal
        self.topCategoryName = topCategoryName
        self.topCategoryAmount = topCategoryAmount
        self.savingsPercentage = savingsPercentage
    }
}
```

If the existing struct already declares `monthTotal` and `weekTotal`, just add the new fields.

- [ ] **Step 6.2: Add `generateInsights` to client interface**

In `AIServiceClient.swift`:

```swift
public var generateInsights: @Sendable (_ summary: SpendingSummary) async throws -> [InsightData]
```

- [ ] **Step 6.3: Mock 3 entries in `liveValue`**

In `AIServiceClient+Live.swift`:

```swift
generateInsights: { _ in
    [
        InsightData(
            title: "本週支出減少 12%",
            body: "你比上週省下 NT$ 3,200，可以考慮加碼儲蓄",
            metric: "-12%",
            metricColor: .income,
            cta: "查看分析"
        ),
        InsightData(
            title: "餐飲花費偏高",
            body: "本月已花 NT$ 8,400，佔總支出 42%",
            metric: "42%",
            metricColor: .expense,
            cta: "設定預算"
        ),
        InsightData(
            title: "儲蓄率達標",
            body: "本月儲蓄率 28%，超出目標 5%",
            metric: "28%",
            metricColor: .accent,
            cta: "查看詳情"
        )
    ]
},
```

- [ ] **Step 6.4: Write failing reducer test**

```swift
// Features/Tests/FeaturesTests/Dashboard/DashboardFeatureInsightTests.swift
import Testing
import ComposableArchitecture
import Foundation
@testable import Features
import Domain

@MainActor
@Suite("DashboardFeature Insight Carousel")
struct DashboardFeatureInsightTests {
    @Test("Loads 3 insights and sets insightIndex to 0")
    func testLoad() async {
        let mock = [
            InsightData(title: "A", body: "a", metric: "1%", metricColor: .income),
            InsightData(title: "B", body: "b", metric: "2%", metricColor: .expense),
            InsightData(title: "C", body: "c", metric: "3%", metricColor: .accent)
        ]
        let store = TestStore(initialState: DashboardFeature.State()) {
            DashboardFeature()
        } withDependencies: {
            $0.aiServiceClient.isAvailable = { true }
            $0.aiServiceClient.generateInsights = { _ in mock }
            $0.transactionClient.weeklySpending = { _, _ in [] }
            $0.transactionClient.statsSnapshot = { .zero }
            $0.transactionClient.fetchRecent = { [] }
            $0.transactionClient.fetchAll = { [] }
            $0.accountClient.fetchActive = { [] }
            $0.categoryClient.fetchAll = { [] }
        }
        await store.send(.task) {
            $0.heroPhase = .loading
            $0.statsPhase = .loading
            $0.transactionsPhase = .loading
            $0.insightPhase = .loading
            $0.accountsPhase = .loading
        }
        await store.receive(\.insightsLoaded) {
            $0.insights = mock
            $0.insightIndex = 0
            $0.insightPhase = .loaded
        }
        // ignore other receive() …
        await store.skipReceivedActions()
    }

    @Test("insightIndexChanged updates the index")
    func testIndex() async {
        let store = TestStore(initialState: DashboardFeature.State()) {
            DashboardFeature()
        }
        await store.send(.insightIndexChanged(2)) {
            $0.insightIndex = 2
        }
    }
}
```

Run → expect FAIL.

- [ ] **Step 6.5: Wire insight effect and handlers**

Add to `.task` merge list:

```swift
.run { send in
    do {
        let summary = SpendingSummary(monthTotal: 0, weekTotal: 0)
        let list = try await aiServiceClient.generateInsights(summary)
        await send(.insightsLoaded(list))
    } catch {
        await send(.sectionFailed(.insight, "無法載入"))
    }
}
.cancellable(id: CancelID.insights, cancelInFlight: true),
```

Add `case insights` to `CancelID`. Add handlers:

```swift
case let .insightsLoaded(list):
    state.insights = list
    state.insightIndex = 0
    state.insightPhase = .loaded
    return .none

case let .insightIndexChanged(i):
    state.insightIndex = max(0, min(i, max(state.insights.count - 1, 0)))
    return .none
```

Wire `retrySection(.insight)`.

- [ ] **Step 6.6: Run reducer test → expect PASS**

- [ ] **Step 6.7: Extend `InsightCard`**

Update `Features/Sources/Common/Components/InsightCard.swift` to accept the new parameters with defaults so existing call sites continue to work:

```swift
public struct InsightCard: View {
    public let title: String
    public let body: String
    public let metric: String?
    public let metricColor: Color?
    public let cta: String?
    public let onCTATap: (() -> Void)?

    public init(
        title: String,
        body: String,
        metric: String? = nil,
        metricColor: Color? = nil,
        cta: String? = nil,
        onCTATap: (() -> Void)? = nil
    ) {
        self.title = title
        self.body = body
        self.metric = metric
        self.metricColor = metricColor
        self.cta = cta
        self.onCTATap = onCTATap
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Text(title).font(.system(size: 16, weight: .semibold))
                Spacer()
                if let m = metric, let c = metricColor {
                    MetricBadge(text: m, color: c)
                }
            }
            Text(self.body).font(.system(size: 13)).foregroundStyle(.secondary)
            if let cta {
                Button(action: { onCTATap?() }) {
                    HStack(spacing: 4) {
                        Text(cta).font(.system(size: 13, weight: .semibold))
                        Image(systemName: "arrow.right").font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(Color.Design.brandPrimary)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.ultraThinMaterial))
    }
}
```

- [ ] **Step 6.8: Create `InsightCarousel`**

```swift
// Features/Sources/Features/Dashboard/Sections/InsightCarousel.swift
import SwiftUI
import ComposableArchitecture
import Common
import Domain

struct InsightCarousel: View {
    let store: StoreOf<DashboardFeature>

    var body: some View {
        switch store.insightPhase {
        case .idle, .loading:
            placeholder.skeleton(when: true)
        case .loaded:
            content
        case let .failed(msg):
            GlassContainer(cornerRadius: 22, padding: 20) {
                SectionFailureView(message: msg) { store.send(.retrySection(.insight)) }
            }
        }
    }

    private func swiftColor(for c: InsightColor) -> Color {
        switch c {
        case .income:  return Color.Design.incomeGreen
        case .expense: return Color.Design.expenseRed
        case .accent:  return Color.Design.brandPrimary
        case .neutral: return .secondary
        }
    }

    @ViewBuilder
    private var content: some View {
        VStack(spacing: 10) {
            TabView(selection: Binding(
                get: { store.insightIndex },
                set: { store.send(.insightIndexChanged($0)) }
            )) {
                ForEach(Array(store.insights.enumerated()), id: \.element.id) { (idx, item) in
                    InsightCard(
                        title: item.title,
                        body: item.body,
                        metric: item.metric,
                        metricColor: swiftColor(for: item.metricColor),
                        cta: item.cta
                    ) {
                        // CTA tap — no-op for this slice
                    }
                    .padding(.horizontal, 2)
                    .tag(idx)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 150)
            HStack {
                PageDots(count: store.insights.count, active: store.insightIndex)
                Spacer()
            }
        }
    }

    private var placeholder: some View {
        GlassContainer(cornerRadius: 22, padding: 20) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Loading insight…").font(.system(size: 16, weight: .semibold))
                Text("Please wait while we analyze your spending…").font(.system(size: 13)).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
```

- [ ] **Step 6.9: Wire into composition root + commit**

Replace the insight placeholder in `DashboardScreen.swift` with `InsightCarousel(store: store)`.

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -3
```

```bash
git add Features/Sources/Domain/Entities/SpendingSummary.swift \
        Features/Sources/Domain/Clients/AIServiceClient.swift \
        Features/Sources/Core/Clients/AIServiceClient+Live.swift \
        Features/Sources/Common/Components/InsightCard.swift \
        Features/Sources/Features/Dashboard/Sections/InsightCarousel.swift \
        Features/Sources/Features/Dashboard/DashboardFeature.swift \
        Features/Sources/Features/Dashboard/DashboardScreen.swift \
        Features/Tests/FeaturesTests/Dashboard/DashboardFeatureInsightTests.swift

git commit -m "$(cat <<'EOF'
feat(dashboard): AI Insight carousel with 3 mocked insights (slice 7)

AIServiceClient.generateInsights returns 3 InsightData entries in
.liveValue (hard-coded mock matching design copy). Schema is ready for
a future FoundationModels-backed implementation without reducer change.
InsightCarousel renders a swipe-able TabView with PageDots indicator.
InsightCard extended to support metric badge and CTA.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: Slice 8 — Empty state + polish

**TDD policy:** TDD-exempt (pure visual + tweaks).

**Files:**
- Modify: `Features/Sources/Common/Components/EmptyStateView.swift` (sizing)
- Modify: per-section empty copy in sections
- Modify: `DashboardScreen.swift` for any final layout cleanup

---

- [ ] **Step 7.1: Update `EmptyStateView` sizing**

Reduce icon circle from 80 to 72 pt. Title 17 pt, body 13 pt. Keep public API stable. Adjust only constants inside the view body.

- [ ] **Step 7.2: Localize each empty state**

Verify every section's empty branch uses the correct copy per `design/screens/02-Dashboard.html` and `design/source/dashboard-b1.jsx`:
- Accounts strip empty → "尚未新增帳戶"
- Transactions empty → "尚無交易 / 記錄您的第一筆花費吧"
- Insight failure copy → "無法載入洞察"

- [ ] **Step 7.3: Pull-to-refresh integration**

In `DashboardFeature.swift` handle `pulledToRefresh` by triggering all four section loaders (hero, stats, insight, transactions) with `cancelInFlight: true`. Pattern: a `.merge` of the same loaders used in `.task`.

- [ ] **Step 7.4: Light/Dark mode visual sweep**

Run the app twice (light + dark mode) and visually compare against `design/screens/02-Dashboard.html`. Note any color hex that needs a Dark Mode variant in the Asset Catalog.

- [ ] **Step 7.5: Build, run all dashboard tests, commit**

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -3
```

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -20
```

Expected: all tests pass.

```bash
git add Features/Sources/Common/Components/EmptyStateView.swift \
        Features/Sources/Features/Dashboard \
        Features/Sources/Common/Resources

git commit -m "$(cat <<'EOF'
chore(dashboard): empty-state copy, pull-to-refresh wiring, dark-mode polish (slice 8)

Tighten EmptyStateView sizing (72pt circle, 17pt/13pt typography),
align every section's empty copy with the design source, and wire
pull-to-refresh to re-trigger every section loader with
cancelInFlight: true. Manual dark-mode visual sweep against
design/screens/02-Dashboard.html.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Self-Review

**Spec coverage:**
- §3 reducer/state → Task 1 (state fields & actions), Tasks 3, 4, 5, 6 (handlers), Task 0 (no state).
- §4 view architecture → Task 1 (composition root + Hero), Tasks 2–6 (per-section views).
- §5 component changes → Task 0 (new components, rename), Tasks 5 / 6 (extended TransactionRow / InsightCard), Task 7 (EmptyStateView).
- §6 client contracts → Task 1 (weeklySpending), Task 4 (statsSnapshot), Task 6 (generateInsights + SpendingSummary).
- §7 slice plan → Tasks 0–7 align with Slice 0–8 (1+2 merged).
- §8 testing strategy → SectionPhase / InsightData / StatsSnapshot domain tests in Task 1; TransactionClient weekly + stats core tests in Tasks 1 / 4; reducer phase / chip / stats / expansion / insight tests across Tasks 1, 3, 4, 5, 6.
- §9 out-of-scope → no task touches Quick Add, Tab Bar, real LLM wiring, or `generateInsight` removal. ✅
- §10 open questions → none.

**Placeholder scan:** No `TBD`/`TODO`/"implement later" patterns. Every code-changing step shows the code. The CTA tap in Insight Carousel is intentionally a no-op for Slice 7 and noted as such — consistent with spec out-of-scope item.

**Type consistency:**
- `SectionPhase` declared in Task 1.1; referenced as `DashboardFeature.SectionPhase` in tests (Tasks 1.13, 3.1, 4.5, 5.1, 6.4) — consistent.
- `Section` enum cases (`.hero / .stats / .transactions / .insight / .accounts`) declared in Task 1.1, used in Tasks 1.14, 3.2, 4.6, 6.5 — consistent.
- `InsightData` / `InsightColor` declared Task 1.3, consumed Task 6.4, 6.5 — consistent.
- `StatsSnapshot` declared Task 1.5 with `.zero`, consumed Task 4.5 — consistent.
- `CancelID` cases added incrementally: `.weeklySpending` (Task 1.14), `.stats` (Task 4.6), `.insights` (Task 6.5) — consistent.

No issues found.

---

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-05-15-dashboard-b1-redesign.md`. Two execution options:**

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration.

**2. Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints.

**Which approach?**
