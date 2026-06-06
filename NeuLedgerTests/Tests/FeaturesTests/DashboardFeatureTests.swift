import Testing
import Foundation
import ComposableArchitecture
import Domain
@testable import Features

@Suite("DashboardFeature Tests")
struct DashboardFeatureTests {

    // MARK: - Helpers

    private static let sampleCategories: [Domain.Category] = [
        Domain.Category(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            name: "Food",
            icon: "fork.knife",
            color: "#FF6B6B",
            type: .expense,
            sortOrder: 0,
            isDefault: true
        ),
        Domain.Category(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            name: "Salary",
            icon: "banknote",
            color: "#34C759",
            type: .income,
            sortOrder: 0,
            isDefault: true
        ),
    ]

    private static let sampleAccounts: [Account] = [
        Account(
            name: "Bank Account",
            type: .bank,
            icon: "building.columns",
            color: "blue",
            sortOrder: 0
        ),
        Account(
            name: "Wallet",
            type: .cash,
            icon: "wallet.pass",
            color: "green",
            sortOrder: 1
        ),
    ]

    private static let sampleTransactions: [Transaction] = [
        Transaction(
            amount: 120,
            date: Date(timeIntervalSince1970: 1_000_003),
            note: "Lunch",
            accountId: UUID().uuidString,
            type: .expense
        ),
        Transaction(
            amount: 50000,
            date: Date(timeIntervalSince1970: 1_000_002),
            note: "Salary",
            accountId: UUID().uuidString,
            type: .income
        ),
        Transaction(
            amount: 200,
            date: Date(timeIntervalSince1970: 1_000_001),
            note: "Coffee",
            accountId: UUID().uuidString,
            type: .expense
        ),
        Transaction(
            amount: 80,
            date: Date(timeIntervalSince1970: 1_000_000),
            note: "Snack",
            accountId: UUID().uuidString,
            type: .expense
        ),
    ]

    // MARK: - Task 5.1: Stream Updates State Correctly

    @Test("task triggers account and transaction fetches and updates state")
    func testTaskUpdatesState() async throws {
        let store = await TestStore(
            initialState: DashboardFeature.State()
        ) {
            DashboardFeature()
        } withDependencies: {
            $0.date = .constant(Date(timeIntervalSince1970: 0))
            $0.ledgerClient.listActiveAccounts = { Self.sampleAccounts }
            $0.ledgerClient.balances = { [Self.sampleAccounts[0].id: 45000, Self.sampleAccounts[1].id: 1200] }
            $0.ledgerClient.listAll = { _ in Self.sampleTransactions.map { EnrichedTransaction(transaction: $0) } }
            $0.insightsClient.weeklySparkline = { _ in [] }
            $0.insightsClient.todayStats = { _ in .zero }
            $0.ledgerClient.listCategories = { _ in Self.sampleCategories }
            $0.insightsClient.generateInsights = { _ in [] }
        }
        await MainActor.run {
            store.exhaustivity = .off
        }

        await store.send(.task) {
            $0.heroPhase = .loading
            $0.statsPhase = .loading
            $0.transactionsPhase = .loading
            $0.insightPhase = .loading
            $0.accountsPhase = .loading
        }

        // Accounts updated
        await store.receive(\.accountsUpdated) {
            $0.accounts = Self.sampleAccounts
            $0.accountsPhase = .loaded
        }

        // Transactions arrive before balance computation completes (concurrent effects)
        await store.receive(\.transactionsUpdated) {
            let sorted = Self.sampleTransactions.sorted { $0.date > $1.date }
            $0.recentTransactions = sorted
            $0.earliestTransactionDate = sorted.last?.date
            $0.transactionsPhase = .loaded
        }

        // Per-account balances computed (balance effect from accountsUpdated)
        await store.receive(\.accountBalancesComputed) {
            $0.accountBalances = [
                Self.sampleAccounts[0].id: 45000,
                Self.sampleAccounts[1].id: 1200,
            ]
        }
    }

    // MARK: - Step 3C: categoriesLoaded Builds categoryMap

    @Test("categoriesLoaded builds categoryMap keyed by category ID")
    func testCategoriesLoadedBuildsCategoryMap() async throws {
        let store = await TestStore(
            initialState: DashboardFeature.State()
        ) {
            DashboardFeature()
        }

        await store.send(.categoriesLoaded(Self.sampleCategories)) { state in
            state.categoryMap = Dictionary(
                uniqueKeysWithValues: Self.sampleCategories.map { ($0.id, $0) }
            )
        }
    }

    @Test("task fetches categories in parallel and populates categoryMap")
    func testTaskFetchesCategoriesAndPopulatesCategoryMap() async throws {
        let store = await TestStore(
            initialState: DashboardFeature.State()
        ) {
            DashboardFeature()
        } withDependencies: {
            $0.date = .constant(Date(timeIntervalSince1970: 0))
            $0.ledgerClient.listActiveAccounts = { [] }
            $0.ledgerClient.balances = { [:] }
            $0.ledgerClient.listAll = { _ in [] }
            $0.insightsClient.weeklySparkline = { _ in [] }
            $0.insightsClient.todayStats = { _ in .zero }
            $0.ledgerClient.listCategories = { _ in Self.sampleCategories }
            $0.insightsClient.generateInsights = { _ in [] }
        }
        await MainActor.run {
            store.exhaustivity = .off
        }

        await store.send(.task) {
            $0.heroPhase = .loading
            $0.statsPhase = .loading
            $0.transactionsPhase = .loading
            $0.insightPhase = .loading
            $0.accountsPhase = .loading
        }

        await store.receive(\.categoriesLoaded) {
            $0.categoryMap = Dictionary(
                uniqueKeysWithValues: Self.sampleCategories.map { ($0.id, $0) }
            )
        }
    }

    // MARK: - Task 5.4: Delegate Actions Published On User Interactions

    @Test("seeAllTransactionsTapped publishes delegate action")
    func testSeeAllTransactionsTappedDelegate() async throws {
        let store = await TestStore(
            initialState: DashboardFeature.State()
        ) {
            DashboardFeature()
        }

        await store.send(.seeAllTransactionsTapped)
        await store.receive(\.delegate.seeAllTransactionsTapped)
    }

    @Test("transactionTapped with matching transaction presents detail")
    func testTransactionTappedPresentsDetail() async throws {
        let transaction = Transaction(
            amount: 100,
            date: Date(timeIntervalSince1970: 0),
            note: "Test",
            accountId: UUID().uuidString,
            type: .expense
        )
        var initial = DashboardFeature.State()
        initial.recentTransactions = [transaction]

        let store = await TestStore(initialState: initial) {
            DashboardFeature()
        }

        await store.send(.transactionTapped(transaction.id)) {
            $0.detail = TransactionDetailFeature.State(transaction: transaction)
        }

        await store.send(\.detail.dismiss) {
            $0.detail = nil
        }
    }

    @Test("transactionTapped with unknown ID does nothing")
    func testTransactionTappedUnknownId() async throws {
        let store = await TestStore(initialState: DashboardFeature.State()) {
            DashboardFeature()
        }
        await store.send(.transactionTapped(UUID()))
    }

    @Test("addTransactionButtonTapped presents AddTransaction sheet")
    func testAddTransactionButtonTapped() async throws {
        let fixedDate = Date(timeIntervalSince1970: 0)
        let store = await TestStore(
            initialState: DashboardFeature.State()
        ) {
            DashboardFeature()
        } withDependencies: {
            $0.date = .constant(fixedDate)
        }

        await store.send(.addTransactionButtonTapped) {
            $0.addTransaction = AddTransactionFeature.State(mode: .add(.expense), date: fixedDate)
        }
    }

    // MARK: - Task 6: addTransactionWithPrefilledData

    @Test("addTransactionWithPrefilledData presents AddTransaction in .addPrefilled mode")
    func addTransactionWithPrefilledDataPresents() async {
        let extracted = ExtractedTransaction(
            amount: 200, suggestedCategory: "交通",
            description: "搭捷運", type: "expense"
        )
        let fixedDate = Date(timeIntervalSince1970: 0)
        let store = await TestStore(initialState: DashboardFeature.State()) {
            DashboardFeature()
        } withDependencies: {
            $0.ledgerClient.listActiveAccounts = { [] }
            $0.ledgerClient.listAccounts = { [] }
            $0.ledgerClient.listAll = { _ in [] }
            $0.date = .constant(fixedDate)
        }
        await store.send(.addTransactionWithPrefilledData(extracted)) {
            $0.addTransaction = AddTransactionFeature.State(mode: .addPrefilled(extracted), date: fixedDate)
        }
    }
}
