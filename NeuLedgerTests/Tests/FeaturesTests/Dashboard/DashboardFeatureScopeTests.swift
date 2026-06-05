import ComposableArchitecture
import Domain
import Foundation
import Testing

@testable import Features

/// Regression tests for the Dashboard state SSOT refactor.
///
/// Covers the four bugs fixed by the refactor:
/// 1. Chip selection re-queries scoped transactions (was: local slice of a
///    truncated array).
/// 2. `transactionTapped` finds rows beyond the old top-3 cap.
/// 3. AI-insight count cache compares and stores the same number.
/// 4. `earliestTransactionDate` is the scope's true earliest, not
///    min(recent 20).
@Suite("DashboardFeature Scope Query")
struct DashboardFeatureScopeTests {
    private static let accA = Account(name: "A", type: .cash, icon: "", color: "#000000")
    private static let accB = Account(name: "B", type: .bank, icon: "", color: "#000000")

    // MARK: - Bug 1 + 轉帳雙向

    @Test("Selecting an account re-queries scoped transactions, including incoming transfers")
    func testChipSelectReloadsScopedTransactions() async {
        let base = Date(timeIntervalSince1970: 2_000_000)
        let txA = Transaction(
            amount: 100, date: base.addingTimeInterval(-100), note: "a",
            accountId: Self.accA.id, type: .expense
        )
        let txB = Transaction(
            amount: 200, date: base.addingTimeInterval(-200), note: "b",
            accountId: Self.accB.id, type: .expense
        )
        // 轉入 accA 的轉帳：accountId 是 accB（轉出方），toAccountId 是 accA。
        // 雙向語意下它必須出現在 accA 的列表（與 ledger.balance 的雙向一致）。
        let transferIn = Transaction(
            amount: 500, date: base.addingTimeInterval(-300), note: "t",
            accountId: Self.accB.id, toAccountId: Self.accA.id, type: .transfer
        )

        var initial = DashboardFeature.State()
        initial.accounts = [Self.accA, Self.accB]
        initial.accountBalances = [Self.accA.id: 300, Self.accB.id: 700]

        let store = await TestStore(initialState: initial) {
            DashboardFeature()
        } withDependencies: {
            $0.ledgerClient.listAll = { _ in
                [txA, txB, transferIn].map { EnrichedTransaction(transaction: $0) }
            }
            $0.insightsClient.weeklySparkline = { _ in [0, 0, 0, 0, 0, 0, 0] }
            $0.insightsClient.isAIAvailable = { false }
        }
        await MainActor.run { store.exhaustivity = .off }

        await store.send(.accountChipSelected(Self.accA.id)) {
            $0.selectedAccountID = Self.accA.id
            $0.heroPhase = .loading
            $0.transactionsPhase = .loading
        }
        await store.receive(\.transactionsUpdated) {
            $0.recentTransactions = [txA, transferIn]   // txB 被排除；轉入包含
            $0.earliestTransactionDate = transferIn.date
            $0.transactionsPhase = .loaded
        }
        await store.receive(\.weeklySpendingComputed) {
            $0.weeklySpending = [0, 0, 0, 0, 0, 0, 0]
            $0.heroPhase = .loaded
        }
        await store.finish()
        await MainActor.run {
            #expect(store.state.filteredBalance == 300)         // computed：選中帳戶餘額
        }
    }

    @Test("Selecting nil chip re-queries the full ledger scope")
    func testChipSelectAllReloadsGlobalScope() async {
        let base = Date(timeIntervalSince1970: 2_000_000)
        let txA = Transaction(
            amount: 100, date: base.addingTimeInterval(-100), note: "a",
            accountId: Self.accA.id, type: .expense
        )
        let txB = Transaction(
            amount: 200, date: base.addingTimeInterval(-200), note: "b",
            accountId: Self.accB.id, type: .expense
        )

        var initial = DashboardFeature.State()
        initial.selectedAccountID = Self.accA.id
        initial.accountBalances = [Self.accA.id: 300, Self.accB.id: 700]

        let store = await TestStore(initialState: initial) {
            DashboardFeature()
        } withDependencies: {
            $0.ledgerClient.listAll = { _ in
                [txA, txB].map { EnrichedTransaction(transaction: $0) }
            }
            $0.insightsClient.weeklySparkline = { _ in [1, 1, 1, 1, 1, 1, 1] }
            $0.insightsClient.isAIAvailable = { false }
        }
        await MainActor.run { store.exhaustivity = .off }

        await store.send(.accountChipSelected(nil)) {
            $0.selectedAccountID = nil
            $0.heroPhase = .loading
            $0.transactionsPhase = .loading
        }
        await store.receive(\.transactionsUpdated) {
            $0.recentTransactions = [txA, txB]
            $0.earliestTransactionDate = txB.date
            $0.transactionsPhase = .loaded
        }
        await store.finish()
        await MainActor.run {
            #expect(store.state.filteredBalance == 1000)        // computed：totalBalance
        }
    }

    // MARK: - Bug 2

    @Test("transactionTapped finds rows beyond the old top-3 cap")
    func testTransactionTappedBeyondTopThree() async {
        let txs = (0 ..< 6).map { i in
            Transaction(
                amount: Decimal(i + 1),
                date: Date(timeIntervalSince1970: TimeInterval(1_000_000 - i)),
                note: "tx\(i)", accountId: "acc", type: .expense
            )
        }
        var initial = DashboardFeature.State()
        initial.recentTransactions = txs

        let store = await TestStore(initialState: initial) {
            DashboardFeature()
        }
        let fifth = txs[4]   // 第 5 列 —— 舊實作只查得到前 3 筆
        await store.send(.transactionTapped(fifth.id)) {
            $0.detail = TransactionDetailFeature.State(transaction: fifth)
        }
    }

    // MARK: - Bug 3

    @Test("transactionsUpdated with unchanged count does not refetch AI insight")
    func testAIInsightSkippedWhenCountUnchanged() async {
        let base = Date(timeIntervalSince1970: 2_000_000)
        let tx1 = Transaction(amount: 1, date: base, note: "1", accountId: "acc", type: .expense)
        let tx2 = Transaction(amount: 2, date: base.addingTimeInterval(-60), note: "2", accountId: "acc", type: .expense)

        var initial = DashboardFeature.State()
        initial.lastInsightTransactionCount = 2

        // Exhaustive TestStore：若 fetchAIInsight 被誤觸發，未接收的 action 會讓測試失敗。
        let store = await TestStore(initialState: initial) {
            DashboardFeature()
        }
        await store.send(.transactionsUpdated(recent: [tx1, tx2], earliestDate: tx2.date)) {
            $0.recentTransactions = [tx1, tx2]
            $0.earliestTransactionDate = tx2.date
            $0.transactionsPhase = .loaded
        }
    }

    @Test("AI insight response stores the same count the trigger compared against")
    func testAIInsightCountConsistency() async {
        let base = Date(timeIntervalSince1970: 2_000_000)
        let txs = (0 ..< 4).map { i in
            Transaction(
                amount: Decimal(i + 1), date: base.addingTimeInterval(TimeInterval(-i * 60)),
                note: "t\(i)", accountId: "acc", type: .expense
            )
        }
        var initial = DashboardFeature.State()
        initial.lastInsightTransactionCount = 2   // 與新 count(4) 不同 → 觸發

        let store = await TestStore(initialState: initial) {
            DashboardFeature()
        } withDependencies: {
            $0.insightsClient.isAIAvailable = { true }
            $0.insightsClient.generateAIInsight = { _ in "insight" }
        }
        await store.send(.transactionsUpdated(recent: txs, earliestDate: txs.last?.date)) {
            $0.recentTransactions = txs
            $0.earliestTransactionDate = txs.last?.date
            $0.transactionsPhase = .loaded
        }
        await store.receive(\.fetchAIInsight) {
            $0.isLoadingInsight = true
        }
        await store.receive(\.aiInsightResponse.success) {
            $0.isLoadingInsight = false
            $0.aiInsight = "insight"
            $0.lastInsightTransactionCount = 4   // 寫回 == 比較來源（修 Bug 3）
        }
    }

    // MARK: - Bug 4

    @Test("earliestTransactionDate reflects the scope's true earliest, not min(recent 20)")
    func testEarliestDateBeyondRecentWindow() async {
        let base = Date(timeIntervalSince1970: 2_000_000)
        // 25 筆、每天一筆：recent 20 不含最舊那 5 筆。
        let txs = (0 ..< 25).map { i in
            Transaction(
                amount: 1, date: base.addingTimeInterval(TimeInterval(-i * 86_400)),
                note: "t\(i)", accountId: "acc", type: .expense
            )
        }
        let store = await TestStore(initialState: DashboardFeature.State()) {
            DashboardFeature()
        } withDependencies: {
            $0.ledgerClient.listAll = { _ in txs.map { EnrichedTransaction(transaction: $0) } }
            $0.insightsClient.isAIAvailable = { false }
        }
        await store.send(.retrySection(.transactions)) {
            $0.transactionsPhase = .loading
        }
        await store.receive(\.transactionsUpdated) {
            $0.recentTransactions = Array(txs.prefix(20))
            $0.earliestTransactionDate = txs.last!.date   // 第 25 筆：最舊、不在 recent 20 內
            $0.transactionsPhase = .loaded
        }
        // count(20) != lastInsightTransactionCount(nil) → 觸發；isAIAvailable false → 無 state 變化
        await store.receive(\.fetchAIInsight)
    }
}
