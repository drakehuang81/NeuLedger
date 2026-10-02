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

    /// `.accountChipSelected` 回傳 `.merge(transactionsEffect, sparklineEffect)` ——
    /// 兩條互不等待的 `.run`，所以 `transactionsUpdated` 與 `weeklySpendingComputed`
    /// 的相對順序**沒有定義**。這些 store 是 non-exhaustive 的，而 non-exhaustive 的
    /// `receive(\.X)` 會把排在 X 前面的其他 action **吃掉並套用**；於是當順序反過來時，
    /// 第一個 `receive(\.transactionsUpdated)` 會先吞掉 `weeklySpendingComputed`，
    /// 第二個 receive 就永遠等不到而 timeout。
    ///
    /// 改用這個 predicate 收兩次，順序無關。兩條以外沒有第三個候選（merge 只有兩條分支，
    /// 失敗路徑會改送 `sectionFailed`，不在 predicate 內），所以「收兩次」等價於
    /// 「兩條各到一次」；state 由 `store.finish()` 之後的 `#expect` 一次驗完。
    ///
    /// 與 `DashboardFeatureChipTests.isChipReloadOutcome` 同一個改法。
    private static func isChipReloadOutcome(_ action: DashboardFeature.Action) -> Bool {
        switch action {
        case .transactionsUpdated, .weeklySpendingComputed: return true
        default: return false
        }
    }


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
        }
        await MainActor.run { store.exhaustivity = .off }

        await store.send(.accountChipSelected(Self.accA.id)) {
            $0.selectedAccountID = Self.accA.id
            $0.heroPhase = .loading
            $0.transactionsPhase = .loading
        }
        // 順序不定：transactionsUpdated / weeklySpendingComputed —— 見 isChipReloadOutcome。
        await store.receive(Self.isChipReloadOutcome)
        await store.receive(Self.isChipReloadOutcome)
        await store.finish()
        await MainActor.run {
            #expect(store.state.recentTransactions == [txA, transferIn])   // txB 被排除；轉入包含
            #expect(store.state.earliestTransactionDate == transferIn.date)
            #expect(store.state.transactionsPhase == .loaded)
            #expect(store.state.weeklySpending == [0, 0, 0, 0, 0, 0, 0])
            #expect(store.state.heroPhase == .loaded)
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
        }
        await store.send(.retrySection(.transactions)) {
            $0.transactionsPhase = .loading
        }
        await store.receive(\.transactionsUpdated) {
            $0.recentTransactions = Array(txs.prefix(20))
            $0.earliestTransactionDate = txs.last!.date   // 第 25 筆：最舊、不在 recent 20 內
            $0.transactionsPhase = .loaded
        }
    }
}
