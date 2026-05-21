import ComposableArchitecture
import Domain
import Foundation
import Testing

@testable import Features

@Suite("DashboardFeature Chip Selection")
struct DashboardFeatureChipTests {
    private static let accA = Account(name: "A", type: .cash, icon: "", color: "#000000")
    private static let accB = Account(name: "B", type: .bank, icon: "", color: "#000000")

    @Test("Selecting an account sets selectedAccountID, filteredBalance, filteredRecent")
    func testChipSelectAccount() async {
        var initial = DashboardFeature.State()
        initial.totalBalance = 1000
        initial.accountBalances = [Self.accA.id: 300, Self.accB.id: 700]
        initial.topAccounts = [Self.accA, Self.accB]
        let tx1 = Transaction(amount: 100, date: .now, note: "x", categoryId: nil, accountId: Self.accA.id, type: .expense)
        let tx2 = Transaction(amount: 200, date: .now, note: "y", categoryId: nil, accountId: Self.accB.id, type: .expense)
        initial.recentTransactions = [tx1, tx2]
        initial.filteredRecent = [tx1, tx2]
        initial.filteredBalance = 1000

        let store = await TestStore(initialState: initial) {
            DashboardFeature()
        } withDependencies: {
            $0.transactionClient.weeklySpending = { _, _ in [0, 0, 0, 0, 0, 0, 0] }
        }

        await store.send(.accountChipSelected(Self.accA.id)) {
            $0.selectedAccountID = Self.accA.id
            $0.filteredBalance = 300
            $0.filteredRecent = [tx1]
            $0.heroPhase = .loading
        }
        await store.receive(\.weeklySpendingComputed) {
            $0.weeklySpending = [0, 0, 0, 0, 0, 0, 0]
            $0.heroPhase = .loaded
        }
    }

    @Test("Selecting nil chip resets filteredBalance to totalBalance and filteredRecent to all")
    func testChipSelectAll() async {
        var initial = DashboardFeature.State()
        initial.totalBalance = 1000
        initial.accountBalances = [Self.accA.id: 300, Self.accB.id: 700]
        initial.topAccounts = [Self.accA, Self.accB]
        let tx1 = Transaction(amount: 100, date: .now, note: "x", categoryId: nil, accountId: Self.accA.id, type: .expense)
        let tx2 = Transaction(amount: 200, date: .now, note: "y", categoryId: nil, accountId: Self.accB.id, type: .expense)
        initial.recentTransactions = [tx1, tx2]
        initial.selectedAccountID = Self.accA.id
        initial.filteredRecent = [tx1]
        initial.filteredBalance = 300

        let store = await TestStore(initialState: initial) {
            DashboardFeature()
        } withDependencies: {
            $0.transactionClient.weeklySpending = { _, _ in [0, 0, 0, 0, 0, 0, 0] }
        }

        await store.send(.accountChipSelected(nil)) {
            $0.selectedAccountID = nil
            $0.filteredBalance = 1000
            $0.filteredRecent = [tx1, tx2]
            $0.heroPhase = .loading
        }
        await store.receive(\.weeklySpendingComputed) {
            $0.weeklySpending = [0, 0, 0, 0, 0, 0, 0]
            $0.heroPhase = .loaded
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
            $0.transactionClient.weeklySpending = { _, _ in [1, 2, 3, 4, 5, 6, 7] }
        }
        await store.send(.accountChipSelected(Self.accA.id)) {
            $0.selectedAccountID = Self.accA.id
            $0.filteredBalance = 0
            $0.filteredRecent = []
            $0.heroPhase = .loading
        }
        await store.receive(\.weeklySpendingComputed) {
            $0.weeklySpending = [1, 2, 3, 4, 5, 6, 7]
            $0.heroPhase = .loaded
        }
        await MainActor.run {
            #expect(store.state.statsPhase == .loaded)
            #expect(store.state.insightPhase == .loaded)
        }
    }
}
