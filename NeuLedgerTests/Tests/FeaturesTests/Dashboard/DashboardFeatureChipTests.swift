import ComposableArchitecture
import Domain
import Foundation
import Testing

@testable import Features

@Suite("DashboardFeature Chip Selection")
struct DashboardFeatureChipTests {
    private static let accA = Account(name: "A", type: .cash, icon: "", color: "#000000")
    private static let accB = Account(name: "B", type: .bank, icon: "", color: "#000000")

    private static func makeTxs() -> (a: Transaction, b: Transaction) {
        let base = Date(timeIntervalSince1970: 2_000_000)
        return (
            Transaction(amount: 100, date: base, note: "x", accountId: accA.id, type: .expense),
            Transaction(amount: 200, date: base.addingTimeInterval(-60), note: "y", accountId: accB.id, type: .expense)
        )
    }

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
    private static func isChipReloadOutcome(_ action: DashboardFeature.Action) -> Bool {
        switch action {
        case .transactionsUpdated, .weeklySpendingComputed: return true
        default: return false
        }
    }

    @Test("Selecting an account sets selectedAccountID and reloads scoped data")
    func testChipSelectAccount() async {
        let (txA, txB) = Self.makeTxs()
        var initial = DashboardFeature.State()
        initial.accounts = [Self.accA, Self.accB]
        initial.accountBalances = [Self.accA.id: 300, Self.accB.id: 700]

        let store = await TestStore(initialState: initial) {
            DashboardFeature()
        } withDependencies: {
            $0.ledgerClient.listAll = { _ in [txA, txB].map { EnrichedTransaction(transaction: $0) } }
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
            #expect(store.state.recentTransactions == [txA])
            #expect(store.state.earliestTransactionDate == txA.date)
            #expect(store.state.transactionsPhase == .loaded)
            #expect(store.state.weeklySpending == [0, 0, 0, 0, 0, 0, 0])
            #expect(store.state.heroPhase == .loaded)
            #expect(store.state.filteredBalance == 300)
        }
    }

    @Test("Selecting nil chip resets to the global scope")
    func testChipSelectAll() async {
        let (txA, txB) = Self.makeTxs()
        var initial = DashboardFeature.State()
        initial.accounts = [Self.accA, Self.accB]
        initial.accountBalances = [Self.accA.id: 300, Self.accB.id: 700]
        initial.selectedAccountID = Self.accA.id
        initial.recentTransactions = [txA]

        let store = await TestStore(initialState: initial) {
            DashboardFeature()
        } withDependencies: {
            $0.ledgerClient.listAll = { _ in [txA, txB].map { EnrichedTransaction(transaction: $0) } }
            $0.insightsClient.weeklySparkline = { _ in [0, 0, 0, 0, 0, 0, 0] }
        }
        await MainActor.run { store.exhaustivity = .off }

        await store.send(.accountChipSelected(nil)) {
            $0.selectedAccountID = nil
            $0.heroPhase = .loading
            $0.transactionsPhase = .loading
        }
        // 順序不定：transactionsUpdated / weeklySpendingComputed —— 見 isChipReloadOutcome。
        await store.receive(Self.isChipReloadOutcome)
        await store.receive(Self.isChipReloadOutcome)
        await store.finish()
        await MainActor.run {
            #expect(store.state.recentTransactions == [txA, txB])
            #expect(store.state.earliestTransactionDate == txB.date)
            #expect(store.state.transactionsPhase == .loaded)
            #expect(store.state.weeklySpending == [0, 0, 0, 0, 0, 0, 0])
            #expect(store.state.heroPhase == .loaded)
            #expect(store.state.filteredBalance == 1000)   // computed：回到 totalBalance
        }
    }

    @Test("Chip switch does not change statsPhase / insightPhase")
    func testChipDoesNotAffectStatsOrInsight() async {
        var initial = DashboardFeature.State()
        initial.statsPhase = .loaded
        initial.insightPhase = .loaded

        let store = await TestStore(initialState: initial) {
            DashboardFeature()
        } withDependencies: {
            $0.ledgerClient.listAll = { _ in [] }
            $0.insightsClient.weeklySparkline = { _ in [1, 2, 3, 4, 5, 6, 7] }
        }
        await MainActor.run { store.exhaustivity = .off }

        await store.send(.accountChipSelected(Self.accA.id)) {
            $0.selectedAccountID = Self.accA.id
            $0.heroPhase = .loading
            $0.transactionsPhase = .loading
        }
        await store.finish()
        await MainActor.run {
            // TODO(stats-follow-up): StatsRow 連動實作後，此測試改為斷言 statsPhase 轉 loading。
            #expect(store.state.statsPhase == .loaded)
            #expect(store.state.insightPhase == .loaded)
        }
    }
}
