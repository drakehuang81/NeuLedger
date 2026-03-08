import Testing
import Foundation
import ComposableArchitecture
import Domain
@testable import Features

@Suite("DashboardFeature Tests")
struct DashboardFeatureTests {

    // MARK: - Helpers

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
            accountId: UUID(),
            type: .expense
        ),
        Transaction(
            amount: 50000,
            date: Date(timeIntervalSince1970: 1_000_002),
            note: "Salary",
            accountId: UUID(),
            type: .income
        ),
        Transaction(
            amount: 200,
            date: Date(timeIntervalSince1970: 1_000_001),
            note: "Coffee",
            accountId: UUID(),
            type: .expense
        ),
        Transaction(
            amount: 80,
            date: Date(timeIntervalSince1970: 1_000_000),
            note: "Snack",
            accountId: UUID(),
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
            $0.accountClient.fetchActive = { Self.sampleAccounts }
            $0.accountClient.computeBalance = { id in
                if id == Self.sampleAccounts[0].id { return 45000 }
                if id == Self.sampleAccounts[1].id { return 1200 }
                return 0
            }
            $0.transactionClient.fetchRecent = { Self.sampleTransactions }
            $0.aiServiceClient.generateInsight = { _ in "Test insight" }
        }

        await store.send(.task) {
            $0.isLoading = true
        }

        // Accounts updated
        await store.receive(\.accountsUpdated) {
            $0.hasAccounts = true
            $0.topAccounts = Self.sampleAccounts.sorted { $0.sortOrder < $1.sortOrder }
        }

        // Transactions arrive before balance computation completes (concurrent effects)
        await store.receive(\.transactionsUpdated) {
            $0.hasTransactions = true
            $0.recentTransactions = Array(
                Self.sampleTransactions
                    .sorted { $0.date > $1.date }
                    .prefix(3)
            )
            $0.isLoading = false
        }

        // AI insight triggered due to new transaction count != cached count
        await store.receive(\.fetchAIInsight) {
            $0.isLoadingInsight = true
        }

        // Total balance computed (balance effect from accountsUpdated)
        await store.receive(\.totalBalanceComputed) {
            $0.totalBalance = 46200 // 45000 + 1200
        }

        await store.receive(\.aiInsightResponse.success) {
            $0.isLoadingInsight = false
            $0.aiInsight = "Test insight"
            $0.lastInsightTransactionCount = 3
        }
    }

    // MARK: - Task 5.2: AI Cache Invalidation On New Transaction

    @Test("AI insight cache is invalidated when transaction count changes")
    func testAICacheInvalidationOnNewTransaction() async throws {
        // Start with cached insight for 3 transactions
        var initialState = DashboardFeature.State()
        initialState.lastInsightTransactionCount = 3
        initialState.aiInsight = "Old insight"
        initialState.hasTransactions = true
        initialState.recentTransactions = Array(Self.sampleTransactions.prefix(3))

        let store = await TestStore(
            initialState: initialState
        ) {
            DashboardFeature()
        } withDependencies: {
            $0.aiServiceClient.generateInsight = { _ in "Updated insight" }
        }

        // Simulate receiving an updated list with 4 transactions (different count).
        // No state change: sorted top-3 and flags are identical to the initial state.
        await store.send(.transactionsUpdated(Self.sampleTransactions))

        // Cache invalidated — fetch triggered
        await store.receive(\.fetchAIInsight) {
            $0.isLoadingInsight = true
        }

        await store.receive(\.aiInsightResponse.success) {
            $0.isLoadingInsight = false
            $0.aiInsight = "Updated insight"
            $0.lastInsightTransactionCount = 3
        }
    }

    // MARK: - Task 5.3: Pull-to-Refresh Forces AI Insight Update

    @Test("pulledToRefresh forces AI insight update")
    func testPullToRefreshForcesAIUpdate() async throws {
        var initialState = DashboardFeature.State()
        initialState.lastInsightTransactionCount = 3
        initialState.aiInsight = "Old insight"
        initialState.hasTransactions = true

        let store = await TestStore(
            initialState: initialState
        ) {
            DashboardFeature()
        } withDependencies: {
            $0.accountClient.fetchActive = { Self.sampleAccounts }
            $0.accountClient.computeBalance = { _ in 1000 }
            $0.transactionClient.fetchRecent = { Array(Self.sampleTransactions.prefix(3)) }
            $0.aiServiceClient.generateInsight = { _ in "Fresh insight" }
        }

        await store.send(.pulledToRefresh) {
            $0.isLoading = true
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
            $0.hasAccounts = true
            $0.topAccounts = Self.sampleAccounts.sorted { $0.sortOrder < $1.sortOrder }
        }

        // Transactions updated
        await store.receive(\.transactionsUpdated) {
            $0.hasTransactions = true
            $0.recentTransactions = Array(
                Self.sampleTransactions.prefix(3)
                    .sorted { $0.date > $1.date }
            )
            $0.isLoading = false
        }

        // transactionsUpdated triggers a second fetchAIInsight (count 3 != lastInsightTransactionCount 0)
        await store.receive(\.fetchAIInsight) {
            $0.isLoadingInsight = true
        }

        // Total balance computed (balance effect from accountsUpdated)
        await store.receive(\.totalBalanceComputed) {
            $0.totalBalance = 2000 // 1000 * 2 accounts
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

    @Test("accountTapped publishes delegate action with account ID")
    func testAccountTappedDelegate() async throws {
        let accountId = UUID()
        let store = await TestStore(
            initialState: DashboardFeature.State()
        ) {
            DashboardFeature()
        }

        await store.send(.accountTapped(accountId))
        await store.receive(\.delegate.accountTapped)
    }

    @Test("transactionTapped publishes delegate action with transaction ID")
    func testTransactionTappedDelegate() async throws {
        let transactionId = UUID()
        let store = await TestStore(
            initialState: DashboardFeature.State()
        ) {
            DashboardFeature()
        }

        await store.send(.transactionTapped(transactionId))
        await store.receive(\.delegate.transactionTapped)
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

    // MARK: - AI Failure Fallback

    @Test("AI insight failure falls back gracefully")
    func testAIInsightFailure() async throws {
        let store = await TestStore(
            initialState: DashboardFeature.State()
        ) {
            DashboardFeature()
        } withDependencies: {
            $0.aiServiceClient.generateInsight = { _ in
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
