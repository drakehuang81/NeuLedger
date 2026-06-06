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
        await store.receive(\.transactionsUpdated) {
            $0.recentTransactions = [txA]
            $0.earliestTransactionDate = txA.date
            $0.transactionsPhase = .loaded
        }
        await store.receive(\.weeklySpendingComputed) {
            $0.weeklySpending = [0, 0, 0, 0, 0, 0, 0]
            $0.heroPhase = .loaded
        }
        await store.finish()
        await MainActor.run {
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
        await store.receive(\.transactionsUpdated) {
            $0.recentTransactions = [txA, txB]
            $0.earliestTransactionDate = txB.date
            $0.transactionsPhase = .loaded
        }
        await store.receive(\.weeklySpendingComputed) {
            $0.weeklySpending = [0, 0, 0, 0, 0, 0, 0]
            $0.heroPhase = .loaded
        }
        await store.finish()
        await MainActor.run {
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
