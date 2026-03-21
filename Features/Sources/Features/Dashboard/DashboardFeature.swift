import ComposableArchitecture
import Domain
import Foundation

@Reducer
public struct DashboardFeature: Sendable {
    public init() {}

    // MARK: - Cancellation IDs

    private enum CancelID {
        case accountObservation
        case transactionObservation
        case categoryFetch
        case aiInsightFetch
    }

    // MARK: - State

    @ObservableState
    public struct State: Equatable {
        // Aggregated data
        public var totalBalance: Decimal = 0
        public var accountBalances: [Account.ID: Decimal] = [:]
        public var topAccounts: [Account] = []
        public var recentTransactions: [Transaction] = []
        public var categoryMap: [Domain.Category.ID: Domain.Category] = [:]

        // AI Insight
        public var aiInsight: String?
        public var isLoadingInsight: Bool = false
        public var lastInsightTransactionCount: Int?

        // Loading & empty-state flags
        public var isLoading: Bool = false
        public var hasAccounts: Bool = false
        public var hasTransactions: Bool = false

        // Presentation
        @Presents var addTransaction: AddTransactionFeature.State?

        public init() {}
    }

    // MARK: - Action

    public enum Action: Sendable, Equatable {
        // Lifecycle
        case task
        case pulledToRefresh
        case refreshCompleted

        // Data responses
        case accountsUpdated([Account])
        case accountBalancesComputed([Account.ID: Decimal], total: Decimal)
        case transactionsUpdated([Transaction])
        case categoriesLoaded([Domain.Category])

        // AI Insight
        case fetchAIInsight
        case aiInsightResponse(TaskResult<String>)

        // User interactions
        case addTransactionButtonTapped
        // Received from MainTabFeature when the TabBar AI input successfully extracts a transaction.
        case addTransactionWithPrefilledData(ExtractedTransaction)
        case seeAllTransactionsTapped
        case accountTapped(Account.ID)
        case transactionTapped(Transaction.ID)

        // Child features
        case addTransaction(PresentationAction<AddTransactionFeature.Action>)

        // Delegation to parent
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Sendable, Equatable {
            case seeAllTransactionsTapped
            case accountTapped(Account.ID)
            case transactionTapped(Transaction.ID)
        }
    }

    // MARK: - Dependencies

    @Dependency(\.accountClient) var accountClient
    @Dependency(\.transactionClient) var transactionClient
    @Dependency(\.categoryClient) var categoryClient
    @Dependency(\.aiServiceClient) var aiServiceClient
    @Dependency(\.date.now) var now

    // MARK: - Body

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            // MARK: Lifecycle

            // Task 2.1: Start async observation for Accounts and Transactions
            case .task:
                state.isLoading = true
                return .merge(
                    .run { send in
                        // Observe accounts via periodic fetch (simulating AsyncStream observation)
                        let accounts = try await accountClient.fetchActive()
                        await send(.accountsUpdated(accounts))
                    }
                    .cancellable(id: CancelID.accountObservation),

                    .run { send in
                        // Observe transactions via periodic fetch
                        let transactions = try await transactionClient.fetchRecent()
                        await send(.transactionsUpdated(transactions))
                    }
                    .cancellable(id: CancelID.transactionObservation),

                    .run { send in
                        let categories = try await categoryClient.fetchAll()
                        await send(.categoriesLoaded(categories))
                    }
                    .cancellable(id: CancelID.categoryFetch, cancelInFlight: true)
                )

            // Task 2.5: Pull-to-refresh — reload data and force AI insight fetch
            case .pulledToRefresh:
                state.isLoading = true
                // Invalidate AI insight cache
                state.lastInsightTransactionCount = nil
                return .merge(
                    .run { send in
                        let accounts = try await accountClient.fetchActive()
                        await send(.accountsUpdated(accounts))
                    }
                    .cancellable(id: CancelID.accountObservation, cancelInFlight: true),

                    .run { send in
                        let transactions = try await transactionClient.fetchRecent()
                        await send(.transactionsUpdated(transactions))
                    }
                    .cancellable(id: CancelID.transactionObservation, cancelInFlight: true),

                    .run { send in
                        let categories = try await categoryClient.fetchAll()
                        await send(.categoriesLoaded(categories))
                    }
                    .cancellable(id: CancelID.categoryFetch, cancelInFlight: true),

                    // Force a new AI insight fetch
                    .send(.fetchAIInsight)
                )

            case .refreshCompleted:
                state.isLoading = false
                return .none

            // MARK: Data responses

            // Task 2.2: Compute total balance, top accounts, and recent transactions
            case let .accountsUpdated(accounts):
                state.hasAccounts = !accounts.isEmpty
                // Store accounts sorted by sortOrder
                state.topAccounts = accounts
                    .sorted { $0.sortOrder < $1.sortOrder }

                // Compute per-account balances and total concurrently
                return .run { [accounts] send in
                    var balances: [Account.ID: Decimal] = [:]
                    await withTaskGroup(of: (Account.ID, Decimal).self) { group in
                        for account in accounts {
                            group.addTask {
                                let balance = (try? await accountClient.computeBalance(account.id)) ?? 0
                                return (account.id, balance)
                            }
                        }
                        for await (id, balance) in group {
                            balances[id] = balance
                        }
                    }
                    let total = balances.values.reduce(0, +)
                    await send(.accountBalancesComputed(balances, total: total))
                }

            case let .accountBalancesComputed(accounts, total: total):
                state.accountBalances = accounts
                state.totalBalance = total
                return .none

            case let .transactionsUpdated(transactions):
                state.hasTransactions = !transactions.isEmpty
                // Sort by date descending, take top 3
                state.recentTransactions = Array(
                    transactions
                        .sorted { $0.date > $1.date }
                        .prefix(3)
                )
                state.isLoading = false

                // Task 2.4: Invalidate AI insight cache when new transaction data detected
                let currentCount = transactions.count
                if state.lastInsightTransactionCount != currentCount {
                    // New transaction data detected — invalidate and re-fetch
                    return .send(.fetchAIInsight)
                }
                return .none

            case let .categoriesLoaded(categories):
                state.categoryMap = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
                return .none

            // MARK: AI Insight

            // Task 2.3: Fetch AI insight with caching and graceful fallback
            case .fetchAIInsight:
                state.isLoadingInsight = true
                return .run { [transactions = state.recentTransactions] send in
                    // Build a spending summary from recent transactions
                    let totalExpense = transactions
                        .filter { $0.type == .expense }
                        .reduce(Decimal.zero) { $0 + $1.amount }
                    let totalIncome = transactions
                        .filter { $0.type == .income }
                        .reduce(Decimal.zero) { $0 + $1.amount }

                    let summary = SpendingSummary(
                        totalIncome: totalIncome,
                        totalExpense: totalExpense,
                        periodDescription: "Recent"
                    )

                    let insight = try await aiServiceClient.generateInsight(summary)
                    await send(.aiInsightResponse(.success(insight)))
                } catch: { error, send in
                    // Graceful fallback on API failure or timeout
                    await send(.aiInsightResponse(.failure(error)))
                }
                .cancellable(id: CancelID.aiInsightFetch, cancelInFlight: true)

            case let .aiInsightResponse(.success(insight)):
                state.isLoadingInsight = false
                state.aiInsight = insight
                // Cache the current transaction count to avoid unnecessary re-fetches
                state.lastInsightTransactionCount = state.recentTransactions.count
                return .none

            case .aiInsightResponse(.failure):
                state.isLoadingInsight = false
                state.aiInsight = nil
                return .none

            // MARK: User interactions
            case .addTransactionButtonTapped:
                state.addTransaction = AddTransactionFeature.State(mode: .add(.expense), date: now)
                return .none

            case let .addTransactionWithPrefilledData(extracted):
                state.addTransaction = AddTransactionFeature.State(mode: .addPrefilled(extracted), date: now)
                return .none

            case .seeAllTransactionsTapped:
                return .send(.delegate(.seeAllTransactionsTapped))

            case let .accountTapped(id):
                return .send(.delegate(.accountTapped(id)))

            case let .transactionTapped(id):
                return .send(.delegate(.transactionTapped(id)))

            // MARK: Child features
            case .addTransaction(.presented(.delegate(.saved))),
                 .addTransaction(.presented(.delegate(.savedWithTransaction(_)))):
                return .run { send in
                    let transactions = try await transactionClient.fetchRecent()
                    await send(.transactionsUpdated(transactions))
                }

            case .addTransaction:
                return .none

            // MARK: Delegation
            case .delegate:
                return .none
            }
        }
        .ifLet(\.$addTransaction, action: \.addTransaction) {
            AddTransactionFeature()
        }
    }
}
