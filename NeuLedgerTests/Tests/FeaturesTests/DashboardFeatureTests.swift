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
            $0.insightsClient.isAIAvailable = { true }
            $0.insightsClient.generateAIInsight = { _ in "Test insight" }
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

        // AI insight triggered due to new transaction count != cached count
        await store.receive(\.fetchAIInsight) {
            $0.isLoadingInsight = true
        }

        // Per-account balances computed (balance effect from accountsUpdated)
        await store.receive(\.accountBalancesComputed) {
            $0.accountBalances = [
                Self.sampleAccounts[0].id: 45000,
                Self.sampleAccounts[1].id: 1200,
            ]
        }

        await store.receive(\.aiInsightResponse.success) {
            $0.isLoadingInsight = false
            $0.aiInsight = "Test insight"
            $0.lastInsightTransactionCount = 4
        }
    }

    // MARK: - Task 5.2: AI Cache Invalidation On New Transaction

    @Test("AI insight cache is invalidated when transaction count changes")
    func testAICacheInvalidationOnNewTransaction() async throws {
        // Start with cached insight for 3 transactions
        var initialState = DashboardFeature.State()
        initialState.lastInsightTransactionCount = 3
        initialState.aiInsight = "Old insight"
        initialState.recentTransactions = Array(Self.sampleTransactions.prefix(3))

        let store = await TestStore(
            initialState: initialState
        ) {
            DashboardFeature()
        } withDependencies: {
            $0.insightsClient.isAIAvailable = { true }
            $0.insightsClient.generateAIInsight = { _ in "Updated insight" }
        }

        // Simulate receiving an updated list with 4 transactions (different count).
        let sorted = Self.sampleTransactions.sorted { $0.date > $1.date }
        await store.send(.transactionsUpdated(recent: sorted, earliestDate: sorted.last?.date)) {
            $0.recentTransactions = sorted
            $0.earliestTransactionDate = sorted.last?.date
            $0.transactionsPhase = .loaded
        }

        // Cache invalidated — fetch triggered
        await store.receive(\.fetchAIInsight) {
            $0.isLoadingInsight = true
        }

        await store.receive(\.aiInsightResponse.success) {
            $0.isLoadingInsight = false
            $0.aiInsight = "Updated insight"
            $0.lastInsightTransactionCount = 4
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
            $0.insightsClient.isAIAvailable = { true }
            $0.insightsClient.generateAIInsight = { _ in "" }
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

    // MARK: - Task 5.3: Pull-to-Refresh Forces AI Insight Update

    @Test("pulledToRefresh forces AI insight update")
    func testPullToRefreshForcesAIUpdate() async throws {
        var initialState = DashboardFeature.State()
        initialState.lastInsightTransactionCount = 3
        initialState.aiInsight = "Old insight"

        let store = await TestStore(
            initialState: initialState
        ) {
            DashboardFeature()
        } withDependencies: {
            $0.date = .constant(Date(timeIntervalSince1970: 0))
            $0.ledgerClient.listActiveAccounts = { Self.sampleAccounts }
            $0.ledgerClient.balances = { [Self.sampleAccounts[0].id: 1000, Self.sampleAccounts[1].id: 1000] }
            $0.ledgerClient.listAll = { _ in Array(Self.sampleTransactions.prefix(3)).map { EnrichedTransaction(transaction: $0) } }
            $0.insightsClient.weeklySparkline = { _ in [] }
            $0.insightsClient.todayStats = { _ in .zero }
            $0.ledgerClient.listCategories = { _ in Self.sampleCategories }
            $0.insightsClient.isAIAvailable = { true }
            $0.insightsClient.generateAIInsight = { _ in "Fresh insight" }
            $0.insightsClient.generateInsights = { _ in [] }
        }
        await MainActor.run {
            store.exhaustivity = .off
        }

        await store.send(.pulledToRefresh) {
            $0.lastInsightTransactionCount = nil // Cache invalidated
        }

        // fetchAIInsight is sent synchronously as part of the merge
        await store.receive(\.fetchAIInsight) {
            $0.isLoadingInsight = true
        }

        // AI insight resolves before account/transaction data arrives
        await store.receive(\.aiInsightResponse.success) {
            $0.isLoadingInsight = false
            $0.aiInsight = "Fresh insight"
            $0.lastInsightTransactionCount = 0 // recentTransactions is still empty at this point
        }

        // Accounts updated
        await store.receive(\.accountsUpdated) {
            $0.accounts = Self.sampleAccounts
            $0.accountsPhase = .loaded
        }

        // Transactions updated
        await store.receive(\.transactionsUpdated) {
            let sorted = Array(Self.sampleTransactions.prefix(3)).sorted { $0.date > $1.date }
            $0.recentTransactions = sorted
            $0.earliestTransactionDate = sorted.last?.date
            $0.transactionsPhase = .loaded
        }

        // transactionsUpdated triggers a second fetchAIInsight (count 3 != lastInsightTransactionCount 0)
        await store.receive(\.fetchAIInsight) {
            $0.isLoadingInsight = true
        }

        // Per-account balances computed (balance effect from accountsUpdated)
        await store.receive(\.accountBalancesComputed) {
            $0.accountBalances = [
                Self.sampleAccounts[0].id: 1000,
                Self.sampleAccounts[1].id: 1000,
            ]
        }

        await store.receive(\.aiInsightResponse.success) {
            $0.isLoadingInsight = false
            $0.aiInsight = "Fresh insight"
            $0.lastInsightTransactionCount = 3
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
            $0.insightsClient.isAIAvailable = { false }
            $0.insightsClient.generateAIInsight = { _ in "" }
            $0.date = .constant(fixedDate)
        }
        await store.send(.addTransactionWithPrefilledData(extracted)) {
            $0.addTransaction = AddTransactionFeature.State(mode: .addPrefilled(extracted), date: fixedDate)
        }
    }

    // MARK: - AI Failure Fallback

    @Test("AI insight failure falls back gracefully")
    func testAIInsightFailure() async throws {
        let store = await TestStore(
            initialState: DashboardFeature.State()
        ) {
            DashboardFeature()
        } withDependencies: {
            $0.insightsClient.isAIAvailable = { true }
            $0.insightsClient.generateAIInsight = { _ in
                throw NSError(domain: "AI", code: -1)
            }
        }

        await store.send(.fetchAIInsight) {
            $0.isLoadingInsight = true
        }

        await store.receive(\.aiInsightResponse.failure) {
            $0.isLoadingInsight = false
            $0.aiInsight = nil
        }
    }
}
