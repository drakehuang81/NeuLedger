# Transaction Detail Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor `TransactionDetailFeature` + `TransactionDetailView` into a half↔full bottom-sheet experience with TxHero, on-device AI insight, detent-aware sections, and a 5-second delayed-delete + Undo flow.

**Architecture:** Reuse the existing `@Presents var transactionDetail` entry points unchanged. Inside the sheet, use SwiftUI's native `.presentationDetents([.medium, .large])` for half↔full. Insight is computed client-side via a new `DatabaseClient.detailStats(for:)` helper exposed through `transactionClient.detailStats`. Delete becomes a 5s `cancellable` effect — `Undo` cancels the effect; expiry runs the real `transactionClient.delete`.

**Tech Stack:** SwiftUI (iOS 26 Liquid Glass), TCA v1.23.1, SwiftData, Swift Testing, Foundation Models (not used this round).

**Spec:** `docs/superpowers/specs/2026-05-15-transaction-detail-redesign-design.md`

---

## File Structure

**Create:**

| Path | Purpose |
|---|---|
| `Features/Sources/Domain/Entities/TransactionInsight.swift` | Insight value type + `Kind` enum |
| `Features/Sources/Common/Components/DetailField.swift` | Label-value row used in Fields card |
| `Features/Sources/Common/Components/AccountChip.swift` | Icon + name + type-caption account chip |
| `Features/Sources/Features/Transactions/Detail/TxHero.swift` | Category pill + amount + title + AI badge |
| `Features/Sources/Features/Transactions/Detail/AIInsightCard.swift` | Insight card with 4 `Kind` branches |
| `Features/Sources/Features/Transactions/Detail/DetailFieldsCard.swift` | Account / Date / Note rows + transfer From/To |
| `Features/Sources/Features/Transactions/Detail/ActivityCard.swift` | Activity log (full detent only) |
| `Features/Sources/Features/Transactions/Detail/TagsRow.swift` | Tag pills row (full detent only) |
| `Features/Sources/Features/Transactions/Detail/UndoBanner.swift` | Glass capsule floating bottom |
| `Features/Tests/DomainTests/Entities/TransactionInsightTests.swift` | Insight equatable / sendable |
| `Features/Tests/CoreTests/Clients/TransactionClientDetailStatsTests.swift` | Core stats computation |
| `Features/Tests/FeaturesTests/TransactionDetailFeatureDeleteWindowTests.swift` | 5s delete + undo |
| `Features/Tests/FeaturesTests/TransactionDetailFeatureInsightTests.swift` | Insight load |
| `Features/Tests/FeaturesTests/TransactionDetailFeatureDetentTests.swift` | Detent change |

**Modify:**

| Path | Change |
|---|---|
| `Features/Sources/Domain/Clients/TransactionClient.swift` | Add `detailStats` closure |
| `Features/Sources/Core/Persistence/DatabaseClient.swift` | Add `detailStats(for:)` helper |
| `Features/Sources/Core/Clients/TransactionClient+Live.swift` | Wire `detailStats` closure |
| `Features/Sources/Features/Transactions/TransactionDetailFeature.swift` | New state fields, actions, 5s delete window |
| `Features/Sources/Features/Transactions/TransactionDetailView.swift` | Rewrite as detent-aware sheet |
| `NeuLedger/Resources/Localizable.xcstrings` | New keys (en + zh-Hant) |
| `Features/Tests/FeaturesTests/TransactionDetailFeatureTests.swift` | Stub new client method in deps |

---

## Conventions

- All steps run on `developer` branch unless instructed otherwise.
- Build command (Tasks 0–8): `xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
- Test command (Tasks 1–8): `xcodebuild test -project NeuLedger.xcodeproj -scheme Features -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
- Single-suite test command: `xcodebuild test -project NeuLedger.xcodeproj -scheme Features -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:FeaturesTests/<Suite>`
- Localized strings always use `String(localized: "key", bundle: .main)` from Features/Core; `Text("key")` from Common is OK because Common views are consumed inside Features which sets bundle correctly via SwiftUI.
- Commit each task at the end. Co-author trailer: `Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>`

---

## Task 0: Common primitives (DetailField + AccountChip)

**Files:**
- Create: `Features/Sources/Common/Components/DetailField.swift`
- Create: `Features/Sources/Common/Components/AccountChip.swift`

- [ ] **Step 1: Create `DetailField.swift`**

```swift
import SwiftUI

/// A label-value row used inside a Glass details card.
///
/// Layout: 76pt monospaced UPPERCASE label on the left, value content
/// flexible right. Optional bottom divider — pass `showsDivider: false`
/// on the last row.
public struct DetailField<Value: View>: View {
    private let labelKey: LocalizedStringKey
    private let dense: Bool
    private let showsDivider: Bool
    private let value: () -> Value

    public init(
        _ labelKey: LocalizedStringKey,
        dense: Bool = false,
        showsDivider: Bool = true,
        @ViewBuilder value: @escaping () -> Value
    ) {
        self.labelKey = labelKey
        self.dense = dense
        self.showsDivider = showsDivider
        self.value = value
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 14) {
                Text(labelKey)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.Design.textSecondary)
                    .frame(width: 76, alignment: .leading)
                value()
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.Design.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, dense ? 10 : 14)

            if showsDivider {
                Divider()
            }
        }
    }
}
```

- [ ] **Step 2: Create `AccountChip.swift`**

```swift
import Domain
import SwiftUI

/// A small chip showing an account's icon, name, and type caption.
///
/// Used inside DetailFieldsCard rows for Account / From / To.
public struct AccountChip: View {
    private let account: Account
    private let dense: Bool

    public init(account: Account, dense: Bool = false) {
        self.account = account
        self.dense = dense
    }

    public var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(swatch.opacity(0.15))
                Image(systemName: account.icon.isEmpty ? "wallet.pass" : account.icon)
                    .font(.system(size: dense ? 12 : 14, weight: .medium))
                    .foregroundStyle(swatch)
                    .symbolRenderingMode(.hierarchical)
            }
            .frame(width: dense ? 22 : 26, height: dense ? 22 : 26)

            VStack(alignment: .leading, spacing: 1) {
                Text(account.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.Design.textPrimary)
                Text(account.type.displayKey)
                    .font(.system(size: 9, weight: .regular, design: .monospaced))
                    .tracking(1)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.Design.textSecondary)
            }
        }
    }

    private var swatch: Color {
        Color(hex: account.color) ?? Color.Design.accent
    }
}

private extension AccountType {
    /// Returns a LocalizedStringKey for this account type's caption.
    var displayKey: LocalizedStringKey {
        switch self {
        case .cash: return "account_type_cash"
        case .bank: return "account_type_bank"
        case .creditCard: return "account_type_credit_card"
        case .eWallet: return "account_type_ewallet"
        }
    }
}
```

- [ ] **Step 3: Verify `Color(hex:)` exists in Common**

```bash
grep -rn "init?(hex:" Features/Sources/Common
```

Expected: at least one match (e.g., in `Color+Hex.swift`). If no match, halt and ask — this initializer is required.

- [ ] **Step 4: Verify `account_type_*` localization keys exist**

```bash
grep -n "account_type_" NeuLedger/Resources/Localizable.xcstrings | head
```

If keys missing, add them in Task 6 (i18n batch). Otherwise no action.

- [ ] **Step 5: Build**

```
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 6: Commit**

```bash
git add Features/Sources/Common/Components/DetailField.swift Features/Sources/Common/Components/AccountChip.swift
git commit -m "$(cat <<'EOF'
feat(common): add DetailField and AccountChip primitives

Used by Transaction Detail redesign for label-value rows and
account display in the From/To/Account fields.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 1: Domain — `TransactionInsight` entity + client method

**Files:**
- Create: `Features/Sources/Domain/Entities/TransactionInsight.swift`
- Modify: `Features/Sources/Domain/Clients/TransactionClient.swift`
- Create: `Features/Tests/DomainTests/Entities/TransactionInsightTests.swift`

- [ ] **Step 1: Write the failing test**

Create `Features/Tests/DomainTests/Entities/TransactionInsightTests.swift`:

```swift
import Foundation
import Testing
@testable import Domain

@Suite("TransactionInsight Tests")
struct TransactionInsightTests {

    @Test("Same kinds are equal")
    func testEquatableSameKind() {
        let a = TransactionInsight(kind: .transfer(monthCount: 2, monthTotal: 5500))
        let b = TransactionInsight(kind: .transfer(monthCount: 2, monthTotal: 5500))
        #expect(a == b)
    }

    @Test("Different kinds are not equal")
    func testEquatableDifferentKind() {
        let a = TransactionInsight(kind: .transfer(monthCount: 2, monthTotal: 5500))
        let b = TransactionInsight(kind: .fallback(monthlyCategoryCount: 5))
        #expect(a != b)
    }

    @Test("Insight is Sendable across actor boundary")
    func testSendable() async {
        let insight = TransactionInsight(kind: .fallback(monthlyCategoryCount: 1))
        await Task.detached { _ = insight }.value
    }
}
```

- [ ] **Step 2: Run the test — verify it fails**

```
xcodebuild test -project NeuLedger.xcodeproj -scheme Features -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:FeaturesTests
```

Expected: compile failure — `TransactionInsight` undefined.

- [ ] **Step 3: Create `TransactionInsight.swift`**

```swift
import Foundation

/// An insight derived from a single transaction's surrounding context.
///
/// Computed client-side (no FoundationModels call) by aggregating
/// same-category / same-type transactions in the current month.
public struct TransactionInsight: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        /// Income compared with the most recent prior same-category income.
        case incomeVsLast(percentDelta: Double, lastAmount: Decimal, monthlyCount: Int, netMonth: Decimal)
        /// Expense compared with same-category monthly average.
        case expenseVsCategoryAvg(percentDelta: Double, avg: Decimal, monthlyCount: Int, monthTotal: Decimal)
        /// Transfer — shows monthly transfer activity.
        case transfer(monthCount: Int, monthTotal: Decimal)
        /// Anything we couldn't fit into the above three.
        case fallback(monthlyCategoryCount: Int)
    }

    public let kind: Kind

    public init(kind: Kind) {
        self.kind = kind
    }
}
```

- [ ] **Step 4: Add the client closure**

In `Features/Sources/Domain/Clients/TransactionClient.swift`, append inside the `@DependencyClient public struct TransactionClient`:

```swift
    /// Returns a `TransactionInsight` summarizing this transaction's
    /// context (same-category month aggregates, etc.). Used by
    /// Transaction Detail to render the on-device AI insight card.
    public var detailStats: @Sendable (_ transaction: Transaction) async throws -> TransactionInsight
```

Place it immediately after `statsSnapshot`.

- [ ] **Step 5: Run the test — verify it passes**

```
xcodebuild test -project NeuLedger.xcodeproj -scheme Features -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:FeaturesTests/TransactionInsightTests
```

Expected: 3 tests pass.

- [ ] **Step 6: Build full project**

```
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Expected: BUILD SUCCEEDED. (`testValue = Self()` will auto-cover the new closure.)

- [ ] **Step 7: Commit**

```bash
git add Features/Sources/Domain/Entities/TransactionInsight.swift Features/Sources/Domain/Clients/TransactionClient.swift Features/Tests/DomainTests/Entities/TransactionInsightTests.swift
git commit -m "$(cat <<'EOF'
feat(domain): add TransactionInsight entity and detailStats client method

TransactionInsight wraps a Kind enum covering income/expense/transfer/
fallback variants. detailStats(transaction:) returns the insight to be
shown in Transaction Detail's AI Insight card.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Core — `DatabaseClient.detailStats(for:)` + Live wiring

**Files:**
- Modify: `Features/Sources/Core/Persistence/DatabaseClient.swift`
- Modify: `Features/Sources/Core/Clients/TransactionClient+Live.swift`
- Create: `Features/Tests/CoreTests/Clients/TransactionClientDetailStatsTests.swift`

- [ ] **Step 1: Write the failing test**

Create `Features/Tests/CoreTests/Clients/TransactionClientDetailStatsTests.swift`:

```swift
import Dependencies
import Foundation
import Testing
import Domain
@testable import Core

@Suite("DatabaseClient.detailStats Tests")
struct TransactionClientDetailStatsTests {

    private static func freshClient() -> DatabaseClient {
        // Use testValue (in-memory) and create a fresh container per test by
        // re-evaluating the static; for deterministic isolation, we use a
        // unique configuration in-line.
        return DatabaseClient.testValue
    }

    private static let accountID = UUID(uuidString: "11000000-0000-0000-0000-000000000001")!
    private static let categoryFood = UUID(uuidString: "33000000-0000-0000-0000-000000000001")!
    private static let categorySalary = UUID(uuidString: "33000000-0000-0000-0000-000000000002")!

    @Test("Expense returns expenseVsCategoryAvg with month total and count")
    func testExpenseStats() async throws {
        let client = Self.freshClient()
        let now = Date()
        // Insert two food expenses this month including the subject
        let subject = Transaction(amount: 250, date: now, categoryId: Self.categoryFood, accountId: Self.accountID, type: .expense)
        let other = Transaction(amount: 150, date: now, categoryId: Self.categoryFood, accountId: Self.accountID, type: .expense)
        try client.add(subject, as: SDTransaction.self)
        try client.add(other, as: SDTransaction.self)

        let insight = try client.detailStats(for: subject)

        guard case let .expenseVsCategoryAvg(_, avg, count, total) = insight.kind else {
            Issue.record("Expected expenseVsCategoryAvg, got \(insight.kind)")
            return
        }
        #expect(count == 2)
        #expect(total == 400)
        #expect(avg == 200)
    }

    @Test("Income returns incomeVsLast with monthly count")
    func testIncomeStats() async throws {
        let client = Self.freshClient()
        let now = Date()
        let prior = Transaction(amount: 48_000, date: Calendar.current.date(byAdding: .day, value: -2, to: now)!, categoryId: Self.categorySalary, accountId: Self.accountID, type: .income)
        let subject = Transaction(amount: 50_000, date: now, categoryId: Self.categorySalary, accountId: Self.accountID, type: .income)
        try client.add(prior, as: SDTransaction.self)
        try client.add(subject, as: SDTransaction.self)

        let insight = try client.detailStats(for: subject)
        guard case let .incomeVsLast(percentDelta, lastAmount, monthlyCount, _) = insight.kind else {
            Issue.record("Expected incomeVsLast, got \(insight.kind)")
            return
        }
        #expect(lastAmount == 48_000)
        #expect(monthlyCount == 2)
        #expect(abs(percentDelta - ((50_000 - 48_000) / 48_000 * 100)) < 0.01)
    }

    @Test("Transfer returns transfer kind with monthly total")
    func testTransferStats() async throws {
        let client = Self.freshClient()
        let now = Date()
        let other = Transaction(amount: 2500, date: now, accountId: Self.accountID, toAccountId: UUID(), type: .transfer)
        let subject = Transaction(amount: 3000, date: now, accountId: Self.accountID, toAccountId: UUID(), type: .transfer)
        try client.add(other, as: SDTransaction.self)
        try client.add(subject, as: SDTransaction.self)

        let insight = try client.detailStats(for: subject)
        guard case let .transfer(count, total) = insight.kind else {
            Issue.record("Expected transfer, got \(insight.kind)")
            return
        }
        #expect(count == 2)
        #expect(total == 5500)
    }

    @Test("Expense without category falls back")
    func testExpenseFallbackNoCategory() async throws {
        let client = Self.freshClient()
        let subject = Transaction(amount: 100, date: .now, categoryId: nil, accountId: Self.accountID, type: .expense)
        try client.add(subject, as: SDTransaction.self)

        let insight = try client.detailStats(for: subject)
        guard case let .fallback(count) = insight.kind else {
            Issue.record("Expected fallback, got \(insight.kind)")
            return
        }
        #expect(count == 1)
    }
}
```

> **Note:** `DatabaseClient.testValue` is a singleton — multiple suites running concurrently may interfere. If this test file's suite leaks state into other suites, refactor in Step 5 to build a per-test container. For now we rely on isolated ranges (unique UUIDs + month-based filtering).

- [ ] **Step 2: Run — expect compile failure**

```
xcodebuild test -project NeuLedger.xcodeproj -scheme Features -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:FeaturesTests/TransactionClientDetailStatsTests
```

Expected: compile failure on `client.detailStats(for:)`.

- [ ] **Step 3: Add `detailStats(for:)` helper to `DatabaseClient`**

In `Features/Sources/Core/Persistence/DatabaseClient.swift`, add inside the `// MARK: Aggregates` block of the `DatabaseClient` helpers extension (after `statsSnapshot()`):

```swift
    /// Computes a `TransactionInsight` for the given transaction.
    ///
    /// - `.expense` with categoryId → average + count + total of that category
    ///   in the current calendar month.
    /// - `.income` with categoryId → most recent prior amount + monthly count
    ///   + monthly net.
    /// - `.transfer` → monthly transfer count + total.
    /// - Anything else → `.fallback(monthlyCategoryCount:)`.
    func detailStats(for transaction: Transaction) throws -> TransactionInsight {
        let cal = Calendar.current
        let now = Date()
        guard let monthRange = cal.dateInterval(of: .month, for: now) else {
            return TransactionInsight(kind: .fallback(monthlyCategoryCount: 0))
        }
        let monthStart = monthRange.start
        let monthEnd = monthRange.end

        let descriptor = FetchDescriptor<SDTransaction>(
            predicate: #Predicate<SDTransaction> { tx in
                tx.date >= monthStart && tx.date < monthEnd
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let context = makeContext()
        let monthRows = try context.fetch(descriptor)

        switch transaction.type {
        case .expense:
            guard let catId = transaction.categoryId else {
                return TransactionInsight(kind: .fallback(monthlyCategoryCount: 1))
            }
            let sameCategory = monthRows.filter { $0.type == TransactionType.expense.rawValue && $0.categoryId == catId }
            let count = sameCategory.count
            let total = sameCategory.reduce(Decimal(0)) { $0 + $1.amount }
            let avg: Decimal = count > 0 ? total / Decimal(count) : 0
            let avgDouble = NSDecimalNumber(decimal: avg).doubleValue
            let amtDouble = NSDecimalNumber(decimal: transaction.amount).doubleValue
            let percentDelta: Double = avgDouble > 0 ? (amtDouble - avgDouble) / avgDouble * 100 : 0
            return TransactionInsight(kind: .expenseVsCategoryAvg(
                percentDelta: percentDelta,
                avg: avg,
                monthlyCount: count,
                monthTotal: total
            ))

        case .income:
            guard let catId = transaction.categoryId else {
                return TransactionInsight(kind: .fallback(monthlyCategoryCount: 1))
            }
            let sameCategory = monthRows.filter { $0.type == TransactionType.income.rawValue && $0.categoryId == catId }
            let count = sameCategory.count
            // Last prior amount = first of sameCategory whose id != subject.id
            let prior = sameCategory.first(where: { $0.id != transaction.id })
            let lastAmount: Decimal = prior?.amount ?? transaction.amount
            let lastDouble = NSDecimalNumber(decimal: lastAmount).doubleValue
            let amtDouble = NSDecimalNumber(decimal: transaction.amount).doubleValue
            let percentDelta: Double = lastDouble > 0 ? (amtDouble - lastDouble) / lastDouble * 100 : 0
            let monthIncome = monthRows
                .filter { $0.type == TransactionType.income.rawValue }
                .reduce(Decimal(0)) { $0 + $1.amount }
            let monthExpense = monthRows
                .filter { $0.type == TransactionType.expense.rawValue }
                .reduce(Decimal(0)) { $0 + $1.amount }
            return TransactionInsight(kind: .incomeVsLast(
                percentDelta: percentDelta,
                lastAmount: lastAmount,
                monthlyCount: count,
                netMonth: monthIncome - monthExpense
            ))

        case .transfer:
            let transfers = monthRows.filter { $0.type == TransactionType.transfer.rawValue }
            let total = transfers.reduce(Decimal(0)) { $0 + $1.amount }
            return TransactionInsight(kind: .transfer(monthCount: transfers.count, monthTotal: total))
        }
    }
```

- [ ] **Step 4: Wire it through `TransactionClient.liveValue`**

In `Features/Sources/Core/Clients/TransactionClient+Live.swift`, add the new closure inside the `TransactionClient(...)` builder right after `statsSnapshot`:

```swift
            ,
            detailStats: { transaction in
                try databaseClient.detailStats(for: transaction)
            }
```

(Place after the existing `statsSnapshot: { try databaseClient.statsSnapshot() }` line, before the closing paren.)

- [ ] **Step 5: Run tests — expect pass**

```
xcodebuild test -project NeuLedger.xcodeproj -scheme Features -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:FeaturesTests/TransactionClientDetailStatsTests
```

Expected: 4 tests pass.

- [ ] **Step 6: Build**

```
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 7: Commit**

```bash
git add Features/Sources/Core/Persistence/DatabaseClient.swift Features/Sources/Core/Clients/TransactionClient+Live.swift Features/Tests/CoreTests/Clients/TransactionClientDetailStatsTests.swift
git commit -m "$(cat <<'EOF'
feat(core): add detailStats(for:) helper and wire into TransactionClient.live

Computes a TransactionInsight from same-category month aggregates.
Expense → avg/total comparison; income → vs last + monthly net;
transfer → monthly activity; otherwise fallback.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Localization keys (en + zh-Hant)

**Files:**
- Modify: `NeuLedger/Resources/Localizable.xcstrings`

Localization is added all at once here so subsequent UI tasks can reference keys freely.

- [ ] **Step 1: Open `Localizable.xcstrings` and add the following entries**

Add each entry to the `"strings"` dictionary. The format Xcode uses is:

```json
"transaction_detail_title" : {
  "localizations" : {
    "en" : { "stringUnit" : { "state" : "translated", "value" : "Transaction · Detail" } },
    "zh-Hant" : { "stringUnit" : { "state" : "translated", "value" : "交易明細" } }
  }
}
```

Add these keys (en / zh-Hant pairs):

| Key | en | zh-Hant |
|---|---|---|
| `transaction_detail_title` | `Transaction · Detail` | `交易明細` |
| `transaction_detail_ai_filled` | `AI Filled` | `AI 自動填入` |
| `transaction_detail_from` | `From` | `從` |
| `transaction_detail_to` | `To` | `到` |
| `transaction_detail_activity` | `Activity` | `活動紀錄` |
| `transaction_detail_activity_ai` | `Created by AI` | `AI 自動建立` |
| `transaction_detail_activity_manual` | `Created manually` | `手動建立` |
| `transaction_detail_activity_updated` | `Last updated` | `最後更新` |
| `transaction_detail_insight_label` | `NeuLedger AI · On-device` | `NeuLedger AI · 裝置端` |
| `transaction_detail_undo` | `Undo` | `復原` |
| `transaction_detail_undo_deleted` | `Deleted` | `已刪除` |
| `transaction_detail_delete_confirm_title` | `Delete this transaction?` | `刪除這筆交易?` |
| `transaction_detail_delete_confirm_body` | `Deletes immediately, undo within 5 seconds.` | `此操作會立即刪除，5 秒內可復原。` |
| `transaction_insight_income_vs_last` | `%@%@%% vs last (NT$%@). %d income entries this month, net NT$%@.` | `%@%@%% 較上次 (NT$%@)。本月 %d 筆收入,淨值 NT$%@。` |
| `transaction_insight_expense_vs_avg` | `%@%@%% vs %@ avg (NT$%@). %d entries, total NT$%@.` | `%@%@%% 較%@平均 (NT$%@)。本月 %d 筆,合計 NT$%@。` |
| `transaction_insight_transfer` | `Net value unchanged. %d transfers this month, total NT$%@.` | `淨值不變。本月 %d 筆轉帳,合計 NT$%@。` |
| `transaction_insight_fallback` | `Entry #%d for this category this month.` | `本月此類別第 %d 筆。` |
| `account_type_cash` | `Cash` | `現金` |
| `account_type_bank` | `Bank` | `銀行` |
| `account_type_credit_card` | `Credit` | `信用卡` |
| `account_type_ewallet` | `E-Wallet` | `電子錢包` |

> If `account_type_*` keys already exist (Task 0 Step 4 check found them), skip those four rows.

- [ ] **Step 2: Build to confirm catalog parses**

```
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Expected: BUILD SUCCEEDED. (If it fails to parse the xcstrings JSON, fix the JSON syntax and re-run.)

- [ ] **Step 3: Commit**

```bash
git add NeuLedger/Resources/Localizable.xcstrings
git commit -m "$(cat <<'EOF'
i18n(transaction-detail): add keys for redesigned detail sheet

Adds title, AI badge, from/to labels, activity log, insight templates,
undo bar, delete confirmation, and account type captions for en/zh-Hant.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Reducer rewrite — detent, insight, delete window

**Files:**
- Modify: `Features/Sources/Features/Transactions/TransactionDetailFeature.swift`
- Modify: `Features/Tests/FeaturesTests/TransactionDetailFeatureTests.swift` (stub new dependency methods)
- Create: `Features/Tests/FeaturesTests/TransactionDetailFeatureInsightTests.swift`
- Create: `Features/Tests/FeaturesTests/TransactionDetailFeatureDetentTests.swift`
- Create: `Features/Tests/FeaturesTests/TransactionDetailFeatureDeleteWindowTests.swift`

This task changes the reducer to:
1. Load insight in `.task` alongside names.
2. Track `detent` (medium / large).
3. Replace immediate-delete with a 5s cancellable window + Undo.

- [ ] **Step 1: Add a `Detent` enum + new State / Action cases**

Open `TransactionDetailFeature.swift` and replace its contents with:

```swift
import ComposableArchitecture
import Domain
import Foundation

@Reducer
public struct TransactionDetailFeature: Sendable {
    public init() {}

    /// Equatable wrapper for the SwiftUI `PresentationDetent` we expose
    /// to the View — keeps Feature layer free of SwiftUI imports.
    public enum Detent: Equatable, Sendable {
        case medium
        case large
    }

    // MARK: - State

    @ObservableState
    public struct State: Equatable {
        public var transaction: Transaction
        public var categoryName: String?
        public var accountName: String?
        public var toAccountName: String?
        public var account: Account?
        public var toAccount: Account?
        public var insight: TransactionInsight?
        public var detent: Detent = .medium
        public var pendingDelete: Bool = false

        @Presents var editTransaction: AddTransactionFeature.State?
        var showDeleteConfirmation: Bool = false

        public init(transaction: Transaction) {
            self.transaction = transaction
        }
    }

    // MARK: - Action

    public enum Action: Sendable, Equatable {
        case task
        case namesLoaded(
            accountName: String?,
            toAccountName: String?,
            categoryName: String?,
            account: Account?,
            toAccount: Account?
        )
        case insightLoaded(TransactionInsight)
        case insightFailed

        case detentChanged(Detent)

        case editTapped
        case deleteTapped
        case deleteConfirmed
        case deleteCancelled
        case undoTapped
        case deleteWindowExpired
        case dismiss

        case editTransaction(PresentationAction<AddTransactionFeature.Action>)

        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Sendable, Equatable {
            case deleted(Transaction.ID)
            case updated(Transaction)
        }
    }

    // MARK: - Dependencies

    @Dependency(\.transactionClient) var transactionClient
    @Dependency(\.accountClient) var accountClient
    @Dependency(\.categoryClient) var categoryClient
    @Dependency(\.continuousClock) var clock
    @Dependency(\.dismiss) var dismiss

    private enum CancelID: Hashable { case deleteWindow }

    // MARK: - Body

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                let txn = state.transaction
                return .merge(
                    .run { send in
                        async let accounts = accountClient.fetchAll()
                        async let categories = categoryClient.fetchAll()
                        let (a, c) = try await (accounts, categories)
                        let account = a.first { $0.id == txn.accountId }
                        let toAccount = txn.toAccountId.flatMap { id in a.first { $0.id == id } }
                        let categoryName = txn.categoryId.flatMap { id in c.first { $0.id == id }?.name }
                        await send(.namesLoaded(
                            accountName: account?.name,
                            toAccountName: toAccount?.name,
                            categoryName: categoryName,
                            account: account,
                            toAccount: toAccount
                        ))
                    },
                    .run { send in
                        do {
                            let insight = try await transactionClient.detailStats(txn)
                            await send(.insightLoaded(insight))
                        } catch {
                            await send(.insightFailed)
                        }
                    }
                )

            case let .namesLoaded(accountName, toAccountName, categoryName, account, toAccount):
                state.accountName = accountName
                state.toAccountName = toAccountName
                state.categoryName = categoryName
                state.account = account
                state.toAccount = toAccount
                return .none

            case let .insightLoaded(insight):
                state.insight = insight
                return .none

            case .insightFailed:
                state.insight = nil
                return .none

            case let .detentChanged(detent):
                state.detent = detent
                return .none

            case .editTapped:
                state.editTransaction = AddTransactionFeature.State(mode: .edit(state.transaction))
                return .none

            case .deleteTapped:
                state.showDeleteConfirmation = true
                return .none

            case .deleteCancelled:
                state.showDeleteConfirmation = false
                return .none

            case .deleteConfirmed:
                state.showDeleteConfirmation = false
                state.pendingDelete = true
                return .run { send in
                    try await clock.sleep(for: .seconds(5))
                    await send(.deleteWindowExpired)
                }
                .cancellable(id: CancelID.deleteWindow, cancelInFlight: true)

            case .undoTapped:
                state.pendingDelete = false
                return .cancel(id: CancelID.deleteWindow)

            case .deleteWindowExpired:
                state.pendingDelete = false
                let id = state.transaction.id
                return .run { send in
                    try await transactionClient.delete(id)
                    await send(.delegate(.deleted(id)))
                    await dismiss()
                }

            case .dismiss:
                return .run { _ in await dismiss() }

            case let .editTransaction(.presented(.delegate(.savedWithTransaction(t)))):
                state.transaction = t
                state.editTransaction = nil
                return .send(.delegate(.updated(t)))

            case .editTransaction(.presented(.delegate(.saved))):
                state.editTransaction = nil
                return .none

            case .editTransaction(.presented(.delegate(.dismissed))):
                state.editTransaction = nil
                return .none

            case .editTransaction:
                return .none

            case .delegate:
                return .none
            }
        }
        .ifLet(\.$editTransaction, action: \.editTransaction) {
            AddTransactionFeature()
        }
    }
}
```

- [ ] **Step 2: Fix existing tests — `.task` now fans out two effects**

In `Features/Tests/FeaturesTests/TransactionDetailFeatureTests.swift`, the `testTaskLoadsNames` test must be updated: (a) provide a `detailStats` stub, (b) the `.task` send no longer accepts a `Bool` change, but `namesLoaded` now carries 5 fields including `account` / `toAccount`. Replace the test body:

```swift
    @Test(".task loads accountName, toAccountName, categoryName via namesLoaded")
    func testTaskLoadsNames() async {
        let account = Account(
            id: Self.account.id,
            name: "現金", type: .cash, icon: "banknote", color: "#34C759"
        )
        let toAccount = Account(
            id: UUID(uuidString: "11000000-0000-0000-0000-000000000002")!,
            name: "銀行", type: .bank, icon: "building.columns", color: "#3478F6"
        )
        let category = Domain.Category(
            id: UUID(uuidString: "33000000-0000-0000-0000-000000000001")!,
            name: "餐飲", icon: "fork.knife", color: "#FF6B6B", type: .expense
        )

        let txn = Transaction(
            id: Self.sampleTransaction.id,
            amount: 200,
            date: Self.sampleTransaction.date,
            note: "午餐",
            categoryId: category.id,
            accountId: account.id,
            toAccountId: toAccount.id,
            type: .expense
        )

        let stubInsight = TransactionInsight(kind: .fallback(monthlyCategoryCount: 1))

        let store = await TestStore(
            initialState: TransactionDetailFeature.State(transaction: txn)
        ) {
            TransactionDetailFeature()
        } withDependencies: {
            $0.accountClient.fetchAll = { [account, toAccount] }
            $0.categoryClient.fetchAll = { [category] }
            $0.transactionClient.detailStats = { _ in stubInsight }
        }
        store.exhaustivity = .off

        await store.send(.task)
        await store.receive(\.namesLoaded) {
            $0.accountName = "現金"
            $0.toAccountName = "銀行"
            $0.categoryName = "餐飲"
            $0.account = account
            $0.toAccount = toAccount
        }
        await store.receive(\.insightLoaded) {
            $0.insight = stubInsight
        }
    }
```

Also fix `testDeleteConfirmedCallsDeleteAndDismisses` — the new flow goes confirm → pendingDelete → deleteWindowExpired before the actual delete runs. Replace with:

```swift
    @Test("deleteConfirmed enters pending state; window expiry triggers delete + delegate")
    func testDeleteConfirmedCallsDeleteAndDismisses() async {
        let deletedId: LockIsolated<Transaction.ID?> = LockIsolated(nil)
        let id = Self.sampleTransaction.id

        var initialState = TransactionDetailFeature.State(transaction: Self.sampleTransaction)
        initialState.showDeleteConfirmation = true

        let clock = TestClock()
        let store = await TestStore(initialState: initialState) {
            TransactionDetailFeature()
        } withDependencies: {
            $0.transactionClient.delete = { deletedId.setValue($0) }
            $0.continuousClock = clock
            $0.dismiss = DismissEffect { }
        }

        await store.send(.deleteConfirmed) {
            $0.showDeleteConfirmation = false
            $0.pendingDelete = true
        }
        await clock.advance(by: .seconds(5))
        await store.receive(\.deleteWindowExpired) {
            $0.pendingDelete = false
        }
        await store.receive(\.delegate.deleted)

        #expect(deletedId.value == id)
    }
```

- [ ] **Step 3: Create `TransactionDetailFeatureInsightTests.swift`**

```swift
import ComposableArchitecture
import Domain
import Foundation
import Testing

@testable import Features

@MainActor
@Suite("TransactionDetailFeature Insight Tests")
struct TransactionDetailFeatureInsightTests {

    private static let account = Account(name: "現金", type: .cash, icon: "banknote", color: "#34C759")
    private static let sample = Transaction(amount: 100, date: .now, accountId: account.id, type: .expense)

    @Test("insightLoaded sets state.insight")
    func testInsightLoaded() async {
        let store = await TestStore(initialState: TransactionDetailFeature.State(transaction: Self.sample)) {
            TransactionDetailFeature()
        }
        let i = TransactionInsight(kind: .fallback(monthlyCategoryCount: 3))
        await store.send(.insightLoaded(i)) {
            $0.insight = i
        }
    }

    @Test("insightFailed clears insight")
    func testInsightFailed() async {
        var initial = TransactionDetailFeature.State(transaction: Self.sample)
        initial.insight = TransactionInsight(kind: .fallback(monthlyCategoryCount: 1))
        let store = await TestStore(initialState: initial) {
            TransactionDetailFeature()
        }
        await store.send(.insightFailed) {
            $0.insight = nil
        }
    }
}
```

- [ ] **Step 4: Create `TransactionDetailFeatureDetentTests.swift`**

```swift
import ComposableArchitecture
import Domain
import Foundation
import Testing

@testable import Features

@MainActor
@Suite("TransactionDetailFeature Detent Tests")
struct TransactionDetailFeatureDetentTests {

    private static let sample = Transaction(amount: 100, date: .now, accountId: UUID(), type: .expense)

    @Test("detentChanged updates state.detent")
    func testDetentChange() async {
        let store = await TestStore(initialState: TransactionDetailFeature.State(transaction: Self.sample)) {
            TransactionDetailFeature()
        }
        await store.send(.detentChanged(.large)) {
            $0.detent = .large
        }
        await store.send(.detentChanged(.medium)) {
            $0.detent = .medium
        }
    }
}
```

- [ ] **Step 5: Create `TransactionDetailFeatureDeleteWindowTests.swift`**

```swift
import ComposableArchitecture
import Domain
import Foundation
import Testing

@testable import Features

@MainActor
@Suite("TransactionDetailFeature Delete Window Tests")
struct TransactionDetailFeatureDeleteWindowTests {

    private static let sample = Transaction(
        id: UUID(uuidString: "44000000-0000-0000-0000-000000000001")!,
        amount: 100, date: .now, accountId: UUID(), type: .expense
    )

    @Test("undoTapped clears pendingDelete and cancels window — delete never runs")
    func testUndoCancelsWindow() async {
        let deleteCalled: LockIsolated<Bool> = LockIsolated(false)
        let clock = TestClock()

        var initial = TransactionDetailFeature.State(transaction: Self.sample)
        initial.showDeleteConfirmation = true

        let store = await TestStore(initialState: initial) {
            TransactionDetailFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.transactionClient.delete = { _ in deleteCalled.setValue(true) }
            $0.dismiss = DismissEffect { }
        }

        await store.send(.deleteConfirmed) {
            $0.showDeleteConfirmation = false
            $0.pendingDelete = true
        }
        await store.send(.undoTapped) {
            $0.pendingDelete = false
        }
        // Advancing past 5s should not produce deleteWindowExpired because we cancelled.
        await clock.advance(by: .seconds(10))
        #expect(deleteCalled.value == false)
    }

    @Test("window expiry triggers delete then delegate.deleted then dismiss")
    func testExpiryDeletesAndDismisses() async {
        let deletedId: LockIsolated<Transaction.ID?> = LockIsolated(nil)
        let dismissed: LockIsolated<Bool> = LockIsolated(false)
        let clock = TestClock()

        var initial = TransactionDetailFeature.State(transaction: Self.sample)
        initial.showDeleteConfirmation = true

        let store = await TestStore(initialState: initial) {
            TransactionDetailFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.transactionClient.delete = { deletedId.setValue($0) }
            $0.dismiss = DismissEffect { dismissed.setValue(true) }
        }

        await store.send(.deleteConfirmed) {
            $0.showDeleteConfirmation = false
            $0.pendingDelete = true
        }
        await clock.advance(by: .seconds(5))
        await store.receive(\.deleteWindowExpired) {
            $0.pendingDelete = false
        }
        await store.receive(\.delegate.deleted)

        #expect(deletedId.value == Self.sample.id)
        #expect(dismissed.value == true)
    }
}
```

- [ ] **Step 6: Run the full Features test scheme**

```
xcodebuild test -project NeuLedger.xcodeproj -scheme Features -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:FeaturesTests/TransactionDetailFeatureTests -only-testing:FeaturesTests/TransactionDetailFeatureInsightTests -only-testing:FeaturesTests/TransactionDetailFeatureDetentTests -only-testing:FeaturesTests/TransactionDetailFeatureDeleteWindowTests
```

Expected: all pass.

If `TransactionDetailView` no longer compiles (it references old state shape), wait — Task 5 rewrites the View; for this task only the reducer + tests need to compile. If the View causes a compile failure that blocks tests, temporarily comment out the View body and re-add in Task 5. Note this in the commit message.

- [ ] **Step 7: Build app target**

```
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

If View causes build failure, leave it for Task 5. If absolutely needed, stub out the `deleteButton`'s `.send(.deleteConfirmed)` direct path to still work. The existing View already calls `.deleteConfirmed`, which still exists; it just now enters pendingDelete first. So the existing View should still compile — the delete flow simply changes behavior at runtime.

- [ ] **Step 8: Commit**

```bash
git add Features/Sources/Features/Transactions/TransactionDetailFeature.swift Features/Tests/FeaturesTests/TransactionDetailFeatureTests.swift Features/Tests/FeaturesTests/TransactionDetailFeatureInsightTests.swift Features/Tests/FeaturesTests/TransactionDetailFeatureDetentTests.swift Features/Tests/FeaturesTests/TransactionDetailFeatureDeleteWindowTests.swift
git commit -m "$(cat <<'EOF'
feat(transaction-detail): add insight load, detent tracking, 5s delete window

deleteConfirmed now enters a pendingDelete state and starts a 5-second
cancellable timer. undoTapped cancels the window; deleteWindowExpired
runs the actual delete + delegate(.deleted) + dismiss. Insight loads
in parallel with names via task.merge.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: View skeleton — sheet container + detent + TopBar

**Files:**
- Modify: `Features/Sources/Features/Transactions/TransactionDetailView.swift`
- Create: `Features/Sources/Features/Transactions/Detail/TxHero.swift` (placeholder for Task 6)

This task rewrites `TransactionDetailView` as a detent-aware sheet. Hero / fields / insight rendering land as placeholder sections; Tasks 6–8 fill them in.

- [ ] **Step 1: Rewrite `TransactionDetailView.swift`**

Replace entire contents:

```swift
import Common
import ComposableArchitecture
import Domain
import SwiftUI

public struct TransactionDetailView: View {
    @Bindable var store: StoreOf<TransactionDetailFeature>

    public init(store: StoreOf<TransactionDetailFeature>) {
        self.store = store
    }

    private var transaction: Domain.Transaction { store.transaction }

    public var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 18) {
                    TxHero(transaction: transaction, categoryName: store.categoryName)
                    placeholderInsight
                    placeholderFields
                    if store.detent == .large {
                        placeholderActivity
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 120) // leave room for action bar + undo
            }
            .scrollIndicators(.hidden)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                actionBar
            }
            .overlay(alignment: .bottom) {
                if store.pendingDelete {
                    UndoBanner(onUndo: { store.send(.undoTapped) })
                        .padding(.horizontal, 14)
                        .padding(.bottom, 24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.22), value: store.pendingDelete)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common_close")) { store.send(.dismiss) }
                }
                ToolbarItem(placement: .principal) {
                    Text("transaction_detail_title")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .tracking(1.6)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.Design.textSecondary)
                }
            }
            .task { await store.send(.task).finish() }
            .confirmationDialog(
                String(localized: "transaction_detail_delete_confirm_title"),
                isPresented: Binding(
                    get: { store.showDeleteConfirmation },
                    set: { if !$0 { store.send(.deleteCancelled) } }
                ),
                titleVisibility: .visible
            ) {
                Button(String(localized: "common_delete"), role: .destructive) {
                    store.send(.deleteConfirmed)
                }
                Button(String(localized: "common_cancel"), role: .cancel) {
                    store.send(.deleteCancelled)
                }
            } message: {
                Text("transaction_detail_delete_confirm_body")
            }
            .sheet(item: $store.scope(state: \.editTransaction, action: \.editTransaction)) { editStore in
                AddTransactionView(store: editStore)
            }
        }
        .presentationDetents(
            [.medium, .large],
            selection: Binding(
                get: { store.detent == .large ? .large : .medium },
                set: { newValue in
                    store.send(.detentChanged(newValue == .large ? .large : .medium))
                }
            )
        )
        .presentationDragIndicator(.visible)
    }

    // MARK: - Placeholders filled in subsequent tasks

    private var placeholderInsight: some View {
        EmptyView()
    }

    private var placeholderFields: some View {
        EmptyView()
    }

    private var placeholderActivity: some View {
        EmptyView()
    }

    // MARK: - Action bar

    private var actionBar: some View {
        HStack(spacing: 10) {
            Button {
                store.send(.editTapped)
            } label: {
                Label(String(localized: "common_edit"), systemImage: "pencil")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.glassProminent)
            .tint(Color.Design.accent)

            Button(role: .destructive) {
                store.send(.deleteTapped)
            } label: {
                Text("common_delete")
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.glass)
            .tint(Color.Design.expenseRed)
            .disabled(store.pendingDelete)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .background(.ultraThinMaterial)
    }
}
```

- [ ] **Step 2: Create placeholder `TxHero.swift`**

`Features/Sources/Features/Transactions/Detail/TxHero.swift`:

```swift
import Common
import Domain
import SwiftUI

/// Placeholder Hero — final implementation lands in Task 6.
struct TxHero: View {
    let transaction: Transaction
    let categoryName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(transaction.amount.twdFormatted)
                .font(Font.Design.largeTitle.weight(.bold).monospacedDigit())
                .foregroundStyle(transaction.type.amountDisplayColor)
            if let name = categoryName ?? transaction.note {
                Text(name)
                    .font(Font.Design.title3.weight(.semibold))
                    .foregroundStyle(Color.Design.textPrimary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
```

- [ ] **Step 3: Create placeholder `UndoBanner.swift`**

`Features/Sources/Features/Transactions/Detail/UndoBanner.swift`:

```swift
import Common
import SwiftUI

/// Glass capsule shown at the bottom of the sheet while a delete is
/// pending. Tapping Undo cancels the pending delete.
struct UndoBanner: View {
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.Design.incomeGreen)
            Text("transaction_detail_undo_deleted")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.Design.textPrimary)
            Spacer(minLength: 0)
            Button(action: onUndo) {
                Text("transaction_detail_undo")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.Design.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassEffect(Glass.clear.tint(Color.Design.surface), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
```

- [ ] **Step 4: Build**

```
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Expected: BUILD SUCCEEDED. If `Glass.clear.tint(...)` API differs in this codebase, grep how Dashboard uses it (`AccountChipsStrip`, `StatPill`) and copy that exact form.

- [ ] **Step 5: Run all Features tests to confirm nothing else broke**

```
xcodebuild test -project NeuLedger.xcodeproj -scheme Features -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Expected: all pass. If any TransactionsFeature / DashboardFeature tests fail due to View reference breakage, address those before commit.

- [ ] **Step 6: Commit**

```bash
git add Features/Sources/Features/Transactions/TransactionDetailView.swift Features/Sources/Features/Transactions/Detail/TxHero.swift Features/Sources/Features/Transactions/Detail/UndoBanner.swift
git commit -m "$(cat <<'EOF'
feat(transaction-detail): rewrite view as detent-aware sheet skeleton

Switches the sheet to .presentationDetents([.medium, .large]) with the
drag indicator, threads detent state through TCA, and wires the action
bar + UndoBanner overlay. TxHero / Fields / Activity / Insight are
placeholders — filled in by subsequent tasks.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Full `TxHero` + `DetailFieldsCard` + `TagsRow` + `ActivityCard`

**Files:**
- Modify: `Features/Sources/Features/Transactions/Detail/TxHero.swift`
- Create: `Features/Sources/Features/Transactions/Detail/DetailFieldsCard.swift`
- Create: `Features/Sources/Features/Transactions/Detail/TagsRow.swift`
- Create: `Features/Sources/Features/Transactions/Detail/ActivityCard.swift`
- Modify: `Features/Sources/Features/Transactions/TransactionDetailView.swift`

- [ ] **Step 1: Replace `TxHero.swift` with the final implementation**

```swift
import Common
import Domain
import SwiftUI

struct TxHero: View {
    let transaction: Transaction
    let categoryName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            categoryPill
            amountRow
            titleRow
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var categoryPill: some View {
        HStack(spacing: 8) {
            if let icon = transaction.type.heroSymbol {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(transaction.type.amountDisplayColor)
            }
            Text(categoryName ?? Self.fallbackCategoryKey(for: transaction.type))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.Design.textPrimary)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 5)
        .glassEffect(Glass.clear.tint(Color.Design.surface), in: Capsule())
    }

    private var amountRow: some View {
        HStack(alignment: .lastTextBaseline, spacing: 6) {
            Text(verbatim: "NT$")
                .font(.system(size: 20, design: .monospaced))
                .foregroundStyle(Color.Design.textSecondary)
            Text(amountFormatted)
                .font(.system(size: 48, weight: .medium, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(transaction.type.amountDisplayColor)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
    }

    private var titleRow: some View {
        HStack(spacing: 8) {
            Text(displayTitle)
                .font(Font.Design.title3.weight(.semibold))
                .foregroundStyle(Color.Design.textPrimary)
            if transaction.aiSuggested {
                aiFilledBadge
            }
        }
    }

    private var aiFilledBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "sparkles")
                .font(.system(size: 9, weight: .semibold))
            Text("transaction_detail_ai_filled")
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .tracking(0.5)
                .textCase(.uppercase)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 2)
        .foregroundStyle(Color.Design.incomeGreen)
        .background(Color.Design.incomeGreen.opacity(0.15))
        .clipShape(Capsule())
    }

    private var amountFormatted: String {
        let sign: String
        switch transaction.type {
        case .income: sign = "+"
        case .expense: sign = "−"
        case .transfer: sign = ""
        }
        let n = NSDecimalNumber(decimal: transaction.amount)
        let fmt = NumberFormatter()
        fmt.numberStyle = .decimal
        fmt.maximumFractionDigits = 0
        let body = fmt.string(from: n) ?? "0"
        return "\(sign)\(body)"
    }

    private var displayTitle: String {
        if let note = transaction.note, !note.isEmpty { return note }
        if let name = categoryName, !name.isEmpty { return name }
        return Self.fallbackCategoryString(for: transaction.type)
    }

    private static func fallbackCategoryKey(for type: TransactionType) -> LocalizedStringKey {
        switch type {
        case .income: return "transaction_type_income"
        case .expense: return "transaction_type_expense"
        case .transfer: return "transaction_type_transfer"
        }
    }

    private static func fallbackCategoryString(for type: TransactionType) -> String {
        switch type {
        case .income: return String(localized: "transaction_type_income", bundle: .main)
        case .expense: return String(localized: "transaction_type_expense", bundle: .main)
        case .transfer: return String(localized: "transaction_type_transfer", bundle: .main)
        }
    }
}

private extension TransactionType {
    var heroSymbol: String? {
        switch self {
        case .income: return "arrow.down.left.circle.fill"
        case .expense: return "arrow.up.right.circle.fill"
        case .transfer: return "arrow.left.arrow.right.circle.fill"
        }
    }
}
```

> **Note:** `transaction_type_income` / `_expense` / `_transfer` keys are assumed to exist already (the existing app uses them for badge labels). If they don't, add them to xcstrings.

- [ ] **Step 2: Create `DetailFieldsCard.swift`**

```swift
import Common
import Domain
import SwiftUI

struct DetailFieldsCard: View {
    let transaction: Transaction
    let account: Account?
    let toAccount: Account?

    var body: some View {
        VStack(spacing: 0) {
            if transaction.type == .transfer {
                if let from = account {
                    DetailField("transaction_detail_from") { AccountChip(account: from) }
                }
                if let to = toAccount {
                    DetailField("transaction_detail_to") { AccountChip(account: to) }
                }
            } else if let account {
                DetailField("transaction_detail_account") { AccountChip(account: account) }
            }

            DetailField("transaction_detail_date") {
                VStack(alignment: .leading, spacing: 2) {
                    Text(transaction.date, format: .dateTime.year().month(.wide).day())
                    Text(transaction.date, format: .dateTime.hour().minute())
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color.Design.textSecondary)
                }
            }

            if let note = transaction.note, !note.isEmpty {
                DetailField("transaction_detail_note", showsDivider: false) {
                    Text(note)
                        .multilineTextAlignment(.leading)
                }
            }
        }
        .padding(.horizontal, 16)
        .glassEffect(Glass.clear.tint(Color.Design.surface), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
```

- [ ] **Step 3: Create `TagsRow.swift`**

```swift
import Common
import Domain
import SwiftUI

struct TagsRow: View {
    let tags: [Tag]

    var body: some View {
        if tags.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("transaction_detail_tags")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.Design.textSecondary)
                FlowLayout(horizontalSpacing: 6, verticalSpacing: 6) {
                    ForEach(tags) { tag in
                        TagPill(text: tag.name)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(Glass.clear.tint(Color.Design.surface), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }
}
```

- [ ] **Step 4: Create `ActivityCard.swift`**

```swift
import Common
import Domain
import SwiftUI

struct ActivityCard: View {
    let transaction: Transaction

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("transaction_detail_activity")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(Color.Design.textSecondary)

            row(icon: transaction.aiSuggested ? "sparkles" : "circle.fill",
                tint: transaction.aiSuggested ? Color.Design.accent : Color.Design.textSecondary,
                key: transaction.aiSuggested ? "transaction_detail_activity_ai" : "transaction_detail_activity_manual",
                date: transaction.createdAt)

            if transaction.updatedAt > transaction.createdAt.addingTimeInterval(1) {
                row(icon: "pencil.circle",
                    tint: Color.Design.textSecondary,
                    key: "transaction_detail_activity_updated",
                    date: transaction.updatedAt)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(Glass.clear.tint(Color.Design.surface), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func row(icon: String, tint: Color, key: LocalizedStringKey, date: Date) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 16)
            Text(key)
                .font(.system(size: 12))
                .foregroundStyle(Color.Design.textPrimary)
            Spacer(minLength: 0)
            Text(date, style: .relative)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Color.Design.textSecondary)
        }
    }
}
```

- [ ] **Step 5: Wire the cards into `TransactionDetailView`**

In `TransactionDetailView.swift`, replace the three `placeholder*` properties (`placeholderInsight`, `placeholderFields`, `placeholderActivity`) and update the `LazyVStack` body:

```swift
                LazyVStack(spacing: 18) {
                    TxHero(transaction: transaction, categoryName: store.categoryName)
                    placeholderInsight // Task 7 fills this
                    DetailFieldsCard(
                        transaction: transaction,
                        account: store.account,
                        toAccount: store.toAccount
                    )
                    if store.detent == .large {
                        TagsRow(tags: transaction.tags)
                        ActivityCard(transaction: transaction)
                    }
                }
```

Keep `placeholderInsight` for now — Task 7 replaces it.

- [ ] **Step 6: Build**

```
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 7: Run all Features tests**

```
xcodebuild test -project NeuLedger.xcodeproj -scheme Features -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Expected: all pass.

- [ ] **Step 8: Commit**

```bash
git add Features/Sources/Features/Transactions/Detail/TxHero.swift Features/Sources/Features/Transactions/Detail/DetailFieldsCard.swift Features/Sources/Features/Transactions/Detail/TagsRow.swift Features/Sources/Features/Transactions/Detail/ActivityCard.swift Features/Sources/Features/Transactions/TransactionDetailView.swift
git commit -m "$(cat <<'EOF'
feat(transaction-detail): implement Hero, Fields, Tags, and Activity sections

TxHero shows category pill + large monospaced amount + title with
AI-filled badge. DetailFieldsCard renders Account/From-To/Date/Note in
a Glass card. TagsRow and ActivityCard render only in the .large
detent. Activity log uses real createdAt/updatedAt timestamps.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: AI Insight card

**Files:**
- Create: `Features/Sources/Features/Transactions/Detail/AIInsightCard.swift`
- Modify: `Features/Sources/Features/Transactions/TransactionDetailView.swift`

- [ ] **Step 1: Create `AIInsightCard.swift`**

```swift
import Common
import Domain
import SwiftUI

struct AIInsightCard: View {
    let insight: TransactionInsight?
    let categoryName: String?

    var body: some View {
        if let insight {
            VStack(alignment: .leading, spacing: 8) {
                header
                Text(body(for: insight))
                    .font(.system(size: 13))
                    .lineSpacing(2)
                    .foregroundStyle(Color.Design.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(Glass.clear.tint(Color.Design.surface), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.Design.accent)
            Text("transaction_detail_insight_label")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(Color.Design.textSecondary)
        }
    }

    private func body(for insight: TransactionInsight) -> String {
        switch insight.kind {
        case let .incomeVsLast(percentDelta, lastAmount, monthlyCount, netMonth):
            let sign = percentDelta >= 0 ? "+" : "−"
            let pct = String(format: "%.1f", abs(percentDelta))
            return String(
                format: String(localized: "transaction_insight_income_vs_last", bundle: .main),
                sign,
                pct,
                format(lastAmount),
                monthlyCount,
                format(netMonth)
            )
        case let .expenseVsCategoryAvg(percentDelta, avg, monthlyCount, monthTotal):
            let sign = percentDelta >= 0 ? "+" : "−"
            let pct = String(format: "%.0f", abs(percentDelta))
            let label = categoryName ?? String(localized: "transaction_type_expense", bundle: .main)
            return String(
                format: String(localized: "transaction_insight_expense_vs_avg", bundle: .main),
                sign,
                pct,
                label,
                format(avg),
                monthlyCount,
                format(monthTotal)
            )
        case let .transfer(monthCount, monthTotal):
            return String(
                format: String(localized: "transaction_insight_transfer", bundle: .main),
                monthCount,
                format(monthTotal)
            )
        case let .fallback(monthlyCategoryCount):
            return String(
                format: String(localized: "transaction_insight_fallback", bundle: .main),
                monthlyCategoryCount
            )
        }
    }

    private func format(_ decimal: Decimal) -> String {
        let n = NSDecimalNumber(decimal: decimal)
        let fmt = NumberFormatter()
        fmt.numberStyle = .decimal
        fmt.maximumFractionDigits = 0
        return fmt.string(from: n) ?? "0"
    }
}
```

- [ ] **Step 2: Replace `placeholderInsight` in `TransactionDetailView.swift`**

Delete the `private var placeholderInsight: some View { EmptyView() }` line. In the `LazyVStack`, replace `placeholderInsight` with:

```swift
                    AIInsightCard(insight: store.insight, categoryName: store.categoryName)
```

- [ ] **Step 3: Build**

```
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Run all Features tests**

```
xcodebuild test -project NeuLedger.xcodeproj -scheme Features -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add Features/Sources/Features/Transactions/Detail/AIInsightCard.swift Features/Sources/Features/Transactions/TransactionDetailView.swift
git commit -m "$(cat <<'EOF'
feat(transaction-detail): add AI Insight card with kind-specific copy

Renders one of four templates (income vs last, expense vs avg, transfer
summary, fallback) using on-device computed TransactionInsight from
detailStats. Localized en/zh-Hant; gracefully hides when insight is nil.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: Polish — old code removal, accessibility, final tests

**Files:**
- Modify: `Features/Sources/Features/Transactions/TransactionDetailView.swift`
- Verify: no orphaned helpers remain in `TransactionDetailView.swift`

- [ ] **Step 1: Remove the orphaned `placeholderInsight` / `placeholderFields` / `placeholderActivity` empty stubs from `TransactionDetailView.swift`**

Open the file and delete any of these that remain (they were placeholders from Task 5):

```swift
    private var placeholderInsight: some View { EmptyView() }
    private var placeholderFields: some View { EmptyView() }
    private var placeholderActivity: some View { EmptyView() }
```

Confirm the `LazyVStack` now directly references `AIInsightCard`, `DetailFieldsCard`, `TagsRow`, `ActivityCard` with no remaining placeholder identifiers.

- [ ] **Step 2: Add accessibility traits**

In `TransactionDetailView.swift`'s `actionBar`, add `.accessibilityIdentifier` to the Edit and Delete buttons:

```swift
            Button {
                store.send(.editTapped)
            } label: {
                Label(String(localized: "common_edit"), systemImage: "pencil")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.glassProminent)
            .tint(Color.Design.accent)
            .accessibilityIdentifier("transaction_detail_edit_button")

            Button(role: .destructive) {
                store.send(.deleteTapped)
            } label: {
                Text("common_delete")
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.glass)
            .tint(Color.Design.expenseRed)
            .disabled(store.pendingDelete)
            .accessibilityIdentifier("transaction_detail_delete_button")
```

In `UndoBanner.swift`, add `.accessibilityIdentifier("transaction_detail_undo_banner")` to the outer HStack and `.accessibilityIdentifier("transaction_detail_undo_button")` to the Undo button.

- [ ] **Step 3: Sanity-check no hardcoded hex `#FFFFFF` / `#000000` in new files**

```bash
grep -rn "#FFFFFF\|#000000" Features/Sources/Features/Transactions/Detail Features/Sources/Common/Components/DetailField.swift Features/Sources/Common/Components/AccountChip.swift
```

Expected: empty output. If anything matches, replace with `Color.Design.*` semantic colors.

- [ ] **Step 4: Run all Features tests**

```
xcodebuild test -project NeuLedger.xcodeproj -scheme Features -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Expected: all pass — full suite green.

- [ ] **Step 5: Build app target**

```
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 6: Manual smoke (record findings only — no automated assertion)**

Launch the app on iPhone 17 Pro simulator, open Transactions tab, tap a transaction:

- Sheet opens at medium detent with grabber
- Drag to large reveals Tags + Activity sections
- Drag back to medium hides them
- Tap Delete → confirmation dialog → confirm → UndoBanner appears with pendingDelete state
- Wait 5s → sheet dismisses and row disappears from list
- Repeat delete flow, but tap Undo within 5s → banner disappears, transaction remains

If any step fails, fix before commit. If steps succeed, add a short note to the commit message.

- [ ] **Step 7: Commit**

```bash
git add Features/Sources/Features/Transactions/TransactionDetailView.swift Features/Sources/Features/Transactions/Detail/UndoBanner.swift
git commit -m "$(cat <<'EOF'
chore(transaction-detail): final polish and accessibility identifiers

Removes placeholder stubs, adds accessibility identifiers to Edit/Delete/
Undo controls, verifies no hardcoded colors. Manual smoke confirms
detent drag, delete window, and undo all work as designed.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Self-Review

**Spec coverage:**

- TxHero (category pill + amount + title + AI badge) → Task 6
- AI Insight 4 kinds → Tasks 1 (entity) + 2 (compute) + 7 (render)
- DetailFieldsCard with transfer From/To → Task 6
- Tags (full only) → Task 6
- Activity log (full only) → Task 6
- 5s delete + Undo + cancel-on-undo + expiry-runs-delete → Task 4 reducer + Task 5 banner
- swipe-to-dismiss during pendingDelete: relies on the `cancellable(id:)` effect not being cancelled when the View tears down — TCA keeps the effect alive until `dismiss()` resolves; the timer fires and `transactionClient.delete` still runs. ✅ matches spec §11.
- presentationDetents medium/large → Task 5
- i18n en/zh-Hant → Task 3
- Tests covering reducer + Core helper + Domain entity → Tasks 1, 2, 4

**Placeholder scan:** no TBD / TODO / "implement later" in any task body. Each step has runnable code or commands.

**Type consistency:**
- `Detent` enum: defined in Task 4, used in Task 5. ✅
- `TransactionInsight.Kind` cases: defined in Task 1, branched in Task 2 Core, rendered in Task 7. Names match: `incomeVsLast`, `expenseVsCategoryAvg`, `transfer`, `fallback`. ✅
- New state fields (`insight`, `detent`, `pendingDelete`, `account`, `toAccount`): all added in Task 4 State, consumed in Task 5+. ✅
- `namesLoaded` payload expanded from 3 → 5 fields: existing test fixed in Task 4 Step 2. ✅
- `Color.Design.accent` / `Color.Design.surface` / `Color.Design.incomeGreen` / `Color.Design.expenseRed` / `Color.Design.textPrimary` / `Color.Design.textSecondary`: all referenced; these exist per Dashboard usage (`AccountChipsStrip.swift`, `StatPill.swift`). ✅
- `Glass.clear.tint(...)` API: confirmed by `AccountChipsStrip.swift` / `StatPill.swift` in the Dashboard slice 8 amendment. ✅

**Known caveats called out:**
- `account_type_*` keys may already exist (Task 0 Step 4 / Task 3 step note).
- `transaction_type_income/_expense/_transfer` keys are assumed present (Task 6 step 1 note).
- `Color(hex:)` initializer is assumed present (Task 0 Step 3 grep check).

---

## Execution

Plan complete and saved to `docs/superpowers/plans/2026-05-15-transaction-detail-redesign.md`.

**Two execution options:**

1. **Subagent-Driven (recommended)** — Dispatch a fresh subagent per task with two-stage review.
2. **Inline Execution** — Execute tasks in this session with checkpoints.

Which approach?
