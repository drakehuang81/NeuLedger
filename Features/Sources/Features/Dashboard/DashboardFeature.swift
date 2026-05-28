import ComposableArchitecture
import Domain
import Foundation

@Reducer
public struct DashboardFeature: Sendable {
    public init() {}

    // MARK: - Section / Phase

    /// Identifies a Dashboard section for the per-section phase machine.
    public enum Section: Equatable, Sendable {
        case hero
        case stats
        case transactions
        case insight
        case accounts
    }

    /// Per-section view state used to drive the skeleton + retry UX.
    public enum SectionPhase: Equatable, Sendable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    // MARK: - Destination

    @Reducer
    public enum Destination {
        case analysis(AnalysisFeature)
    }

    // MARK: - Cancellation IDs

    private enum CancelID {
        case accountObservation
        case transactionObservation
        case categoryFetch
        case aiInsightFetch
        case weeklySpending
        case stats
        case insights
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

        // Chip filter
        public var selectedAccountID: Account.ID? = nil
        public var filteredBalance: Decimal = 0
        public var weeklySpending: [Decimal] = []
        public var earliestTransactionDate: Date? = nil
        public var filteredRecent: [Transaction] = []

        // Stats (populated by Slice 5)
        public var todaySpending: Decimal = 0
        public var weekSpending: Decimal = 0
        public var savingsPercentage: Double = 0

        // Insight (populated by Slice 7)
        public var insights: [InsightData] = []
        public var insightIndex: Int = 0

        // Transaction row expansion (populated by Slice 6)
        public var expandedTransactionID: Transaction.ID? = nil

        // Per-section view state
        public var heroPhase: SectionPhase = .idle
        public var statsPhase: SectionPhase = .idle
        public var transactionsPhase: SectionPhase = .idle
        public var insightPhase: SectionPhase = .idle
        public var accountsPhase: SectionPhase = .idle

        // Navigation
        public var path: StackState<Destination.State> = StackState()

        // Presentation
        @Presents var addTransaction: AddTransactionFeature.State?
        @Presents var detail: TransactionDetailFeature.State?

        public init() {}
    }

    // MARK: - Action

    public enum Action: Equatable {
        // Lifecycle
        case task
        case pulledToRefresh
        case refreshCompleted

        // Data responses
        case accountsUpdated([Account])
        case accountBalancesComputed([Account.ID: Decimal], total: Decimal)
        case transactionsUpdated([Transaction])
        case categoriesLoaded([Domain.Category])

        // B1 Warm Redesign — section-scoped actions
        case weeklySpendingComputed([Decimal])
        case accountChipSelected(Account.ID?)
        case statsComputed(today: Decimal, week: Decimal, savings: Double)
        case insightsLoaded([InsightData])
        case insightIndexChanged(Int)
        case transactionRowToggled(Transaction.ID)
        case sectionFailed(Section, String)
        case retrySection(Section)

        // AI Insight
        case fetchAIInsight
        case aiInsightResponse(TaskResult<String>)

        // User interactions
        case addTransactionButtonTapped
        case quickActionExpenseTapped
        case quickActionIncomeTapped
        case quickActionTransferTapped
        // Received from MainTabFeature when the TabBar AI input successfully extracts a transaction.
        case addTransactionWithPrefilledData(ExtractedTransaction)
        case seeAllTransactionsTapped
        case accountTapped(Account.ID)
        /// Entry from the "餘額總覽" section header; navigates to Analysis with
        /// the dashboard's currently-selected account filter (nil → portfolio view).
        case analysisShortcutTapped
        case transactionTapped(Transaction.ID)

        // Child features
        case path(StackActionOf<Destination>)
        case addTransaction(PresentationAction<AddTransactionFeature.Action>)
        case detail(PresentationAction<TransactionDetailFeature.Action>)

        // Delegation to parent
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Sendable, Equatable {
            case seeAllTransactionsTapped
            case savedRecurringConfirmation(RecurringTransaction.ID, Date)
        }
    }

    // MARK: - Dependencies

    @Dependency(\.accountClient) var accountClient
    @Dependency(\.transactionClient) var transactionClient
    @Dependency(\.categoryClient) var categoryClient
    @Dependency(\.aiUseCase) var aiUseCase
    @Dependency(\.userSettingsRepository) var userSettingsRepository
    @Dependency(\.date.now) var now

    // MARK: - Body

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            // MARK: Lifecycle

            // Task 2.1: Start async observation for Accounts and Transactions
            case .task:
                state.isLoading = true
                state.heroPhase = .loading
                state.statsPhase = .loading
                state.transactionsPhase = .loading
                state.insightPhase = .loading
                state.accountsPhase = .loading
                return loadAllSections(
                    accountID: state.selectedAccountID,
                    cancelInFlight: false
                )

            // Task 2.5: Pull-to-refresh — reload data and force AI insight fetch
            case .pulledToRefresh:
                state.isLoading = true
                state.lastInsightTransactionCount = nil
                return .merge(
                    loadAllSections(
                        accountID: state.selectedAccountID,
                        cancelInFlight: true
                    ),
                    // Force a new AI insight fetch
                    .send(.fetchAIInsight)
                )

            case .refreshCompleted:
                state.isLoading = false
                return .none

            // MARK: Data responses

            case let .accountsUpdated(accounts):
                state.hasAccounts = !accounts.isEmpty
                state.topAccounts = accounts.sorted { $0.sortOrder < $1.sortOrder }
                state.accountsPhase = .loaded

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

            case let .accountBalancesComputed(balances, total: total):
                state.accountBalances = balances
                state.totalBalance = total
                state.filteredBalance = state.selectedAccountID.flatMap { balances[$0] } ?? total
                return .none

            case let .transactionsUpdated(transactions):
                state.hasTransactions = !transactions.isEmpty
                let sorted = transactions.sorted { $0.date > $1.date }
                state.recentTransactions = Array(sorted.prefix(3))
                state.filteredRecent = state.selectedAccountID
                    .map { id in sorted.filter { $0.accountId == id } }
                    ?? sorted
                state.earliestTransactionDate = transactions.map(\.date).min()
                state.transactionsPhase = .loaded
                state.isLoading = false

                let currentCount = transactions.count
                if state.lastInsightTransactionCount != currentCount {
                    return .send(.fetchAIInsight)
                }
                return .none

            case let .categoriesLoaded(categories):
                // Use `uniquingKeysWith` to tolerate transient duplicates that may
                // appear during a CloudKit sync window (server copies + local seed).
                state.categoryMap = Dictionary(
                    categories.map { ($0.id, $0) },
                    uniquingKeysWith: { first, _ in first }
                )
                return .none

            // MARK: B1 Warm Redesign — section actions

            case let .weeklySpendingComputed(values):
                state.weeklySpending = values
                state.heroPhase = .loaded
                return .none

            case let .sectionFailed(section, message):
                switch section {
                case .hero:         state.heroPhase = .failed(message)
                case .stats:        state.statsPhase = .failed(message)
                case .transactions: state.transactionsPhase = .failed(message)
                case .insight:      state.insightPhase = .failed(message)
                case .accounts:     state.accountsPhase = .failed(message)
                }
                return .none

            case let .retrySection(section):
                switch section {
                case .hero:
                    state.heroPhase = .loading
                    return .run { [accountID = state.selectedAccountID] send in
                        do {
                            let values = try await transactionClient.weeklySpending(accountID, 7)
                            await send(.weeklySpendingComputed(values))
                        } catch {
                            await send(.sectionFailed(.hero, String(localized: "dashboard_section_load_failed", bundle: .main)))
                        }
                    }
                    .cancellable(id: CancelID.weeklySpending, cancelInFlight: true)
                case .accounts:
                    state.accountsPhase = .loading
                    return .run { send in
                        do {
                            let accounts = try await accountClient.fetchActive()
                            await send(.accountsUpdated(accounts))
                        } catch {
                            await send(.sectionFailed(.accounts, String(localized: "dashboard_section_load_failed", bundle: .main)))
                        }
                    }
                    .cancellable(id: CancelID.accountObservation, cancelInFlight: true)
                case .transactions:
                    state.transactionsPhase = .loading
                    return .run { send in
                        do {
                            let txs = try await transactionClient.fetchRecent()
                            await send(.transactionsUpdated(txs))
                        } catch {
                            await send(.sectionFailed(.transactions, String(localized: "dashboard_section_load_failed", bundle: .main)))
                        }
                    }
                    .cancellable(id: CancelID.transactionObservation, cancelInFlight: true)
                case .stats:
                    state.statsPhase = .loading
                    return statsEffect(cancelInFlight: true)
                case .insight:
                    state.insightPhase = .loading
                    return insightsEffect(cancelInFlight: true)
                }

            case let .accountChipSelected(accountID):
                state.selectedAccountID = accountID
                state.filteredBalance = accountID.flatMap { state.accountBalances[$0] } ?? state.totalBalance
                if let id = accountID {
                    state.filteredRecent = state.recentTransactions.filter { $0.accountId == id }
                } else {
                    state.filteredRecent = state.recentTransactions
                }
                state.heroPhase = .loading
                return .run { [accountID] send in
                    do {
                        let v = try await transactionClient.weeklySpending(accountID, 7)
                        await send(.weeklySpendingComputed(v))
                    } catch {
                        await send(.sectionFailed(.hero, String(localized: "dashboard_section_load_failed", bundle: .main)))
                    }
                }
                .cancellable(id: CancelID.weeklySpending, cancelInFlight: true)

            case let .statsComputed(today, week, savings):
                state.todaySpending = today
                state.weekSpending = week
                state.savingsPercentage = savings
                state.statsPhase = .loaded
                return .none

            case let .transactionRowToggled(id):
                state.expandedTransactionID = (state.expandedTransactionID == id) ? nil : id
                return .none

            case let .insightsLoaded(list):
                state.insights = list
                state.insightIndex = 0
                state.insightPhase = .loaded
                return .none

            case let .insightIndexChanged(i):
                let upper = max(state.insights.count - 1, 0)
                state.insightIndex = max(0, min(i, upper))
                return .none

            // MARK: AI Insight

            case .fetchAIInsight:
                guard aiUseCase.isAvailable() else { return .none }
                state.isLoadingInsight = true
                return .run { [transactions = state.recentTransactions] send in
                    let totalExpense = transactions
                        .filter { $0.type == .expense }
                        .reduce(Decimal.zero) { $0 + $1.amount }
                    let totalIncome = transactions
                        .filter { $0.type == .income }
                        .reduce(Decimal.zero) { $0 + $1.amount }

                    let summary = SpendingSummary(
                        totalIncome: totalIncome,
                        totalExpense: totalExpense,
                        periodDescription: String(localized: "dashboard_period_recent", bundle: .main)
                    )

                    let insight = try await aiUseCase.generateInsight(summary)
                    await send(.aiInsightResponse(.success(insight)))
                } catch: { error, send in
                    await send(.aiInsightResponse(.failure(error)))
                }
                .cancellable(id: CancelID.aiInsightFetch, cancelInFlight: true)

            case let .aiInsightResponse(.success(insight)):
                state.isLoadingInsight = false
                state.aiInsight = insight
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

            case .quickActionExpenseTapped:
                state.addTransaction = AddTransactionFeature.State(
                    mode: .add(.expense), date: now
                )
                return .none

            case .quickActionIncomeTapped:
                state.addTransaction = AddTransactionFeature.State(
                    mode: .add(.income), date: now
                )
                return .none

            case .quickActionTransferTapped:
                state.addTransaction = AddTransactionFeature.State(
                    mode: .add(.transfer), date: now
                )
                return .none

            case let .addTransactionWithPrefilledData(extracted):
                state.addTransaction = AddTransactionFeature.State(mode: .addPrefilled(extracted), date: now)
                return .none

            case .seeAllTransactionsTapped:
                return .send(.delegate(.seeAllTransactionsTapped))

            case let .accountTapped(id):
                state.path.append(.analysis(AnalysisFeature.State(selectedAccountId: id)))
                return .none

            case .analysisShortcutTapped:
                state.path.append(.analysis(AnalysisFeature.State(selectedAccountId: state.selectedAccountID)))
                return .none

            case let .transactionTapped(id):
                if let transaction = state.recentTransactions.first(where: { $0.id == id }) {
                    state.detail = TransactionDetailFeature.State(transaction: transaction)
                }
                return .none

            // MARK: Child features
            case .addTransaction(.presented(.delegate(.saved))),
                 .addTransaction(.presented(.delegate(.savedWithTransaction(_)))):
                return .merge(
                    .run { send in
                        async let transactions = transactionClient.fetchRecent()
                        async let accounts = accountClient.fetchActive()
                        let (t, a) = try await (transactions, accounts)
                        await send(.transactionsUpdated(t))
                        await send(.accountsUpdated(a))
                    },
                    statsEffect(cancelInFlight: true),
                    .run { [accountID = state.selectedAccountID] send in
                        do {
                            let values = try await transactionClient.weeklySpending(accountID, 7)
                            await send(.weeklySpendingComputed(values))
                        } catch {
                            await send(.sectionFailed(.hero, String(localized: "dashboard_section_load_failed", bundle: .main)))
                        }
                    }
                    .cancellable(id: CancelID.weeklySpending, cancelInFlight: true)
                )

            case let .addTransaction(.presented(.delegate(.savedRecurringConfirmation(id, newNextDueDate)))):
                return .merge(
                    .run { send in
                        async let transactions = transactionClient.fetchRecent()
                        async let accounts = accountClient.fetchActive()
                        let (t, a) = try await (transactions, accounts)
                        await send(.transactionsUpdated(t))
                        await send(.accountsUpdated(a))
                    },
                    statsEffect(cancelInFlight: true),
                    .run { [accountID = state.selectedAccountID] send in
                        do {
                            let values = try await transactionClient.weeklySpending(accountID, 7)
                            await send(.weeklySpendingComputed(values))
                        } catch {
                            await send(.sectionFailed(.hero, String(localized: "dashboard_section_load_failed", bundle: .main)))
                        }
                    }
                    .cancellable(id: CancelID.weeklySpending, cancelInFlight: true),
                    .send(.delegate(.savedRecurringConfirmation(id, newNextDueDate)))
                )

            case .addTransaction:
                return .none

            case .path:
                return .none

            case .detail(.presented(.delegate(.deleted))),
                 .detail(.presented(.delegate(.updated))):
                return .merge(
                    .run { send in
                        async let transactions = transactionClient.fetchRecent()
                        async let accounts = accountClient.fetchActive()
                        let (t, a) = try await (transactions, accounts)
                        await send(.transactionsUpdated(t))
                        await send(.accountsUpdated(a))
                    },
                    statsEffect(cancelInFlight: true),
                    .run { [accountID = state.selectedAccountID] send in
                        do {
                            let values = try await transactionClient.weeklySpending(accountID, 7)
                            await send(.weeklySpendingComputed(values))
                        } catch {
                            await send(.sectionFailed(.hero, String(localized: "dashboard_section_load_failed", bundle: .main)))
                        }
                    }
                    .cancellable(id: CancelID.weeklySpending, cancelInFlight: true)
                )

            case .detail:
                return .none

            // MARK: Delegation
            case .delegate:
                return .none
            }
        }
        .forEach(\.path, action: \.path)
        .ifLet(\.$addTransaction, action: \.addTransaction) {
            AddTransactionFeature()
        }
        .ifLet(\.$detail, action: \.detail) {
            TransactionDetailFeature()
        }
    }

    // MARK: - Helpers

    /// Loads all dashboard sections concurrently. Each loader has its own
    /// do/catch translating failures into `.sectionFailed(...)` (or, for
    /// categories, swallowing them silently — categories only feed styling).
    private func loadAllSections(
        accountID: Account.ID?,
        cancelInFlight: Bool
    ) -> Effect<Action> {
        .merge(
            .run { send in
                do {
                    let accounts = try await accountClient.fetchActive()
                    await send(.accountsUpdated(accounts))
                } catch {
                    await send(.sectionFailed(.accounts, String(localized: "dashboard_section_load_failed", bundle: .main)))
                }
            }
            .cancellable(id: CancelID.accountObservation, cancelInFlight: cancelInFlight),

            .run { send in
                do {
                    let transactions = try await transactionClient.fetchRecent()
                    await send(.transactionsUpdated(transactions))
                } catch {
                    await send(.sectionFailed(.transactions, String(localized: "dashboard_section_load_failed", bundle: .main)))
                }
            }
            .cancellable(id: CancelID.transactionObservation, cancelInFlight: cancelInFlight),

            .run { send in
                do {
                    let categories = try await categoryClient.fetchAll()
                    await send(.categoriesLoaded(categories))
                } catch {
                    // Categories feed UI styling; failure leaves the cached map intact.
                }
            }
            .cancellable(id: CancelID.categoryFetch, cancelInFlight: cancelInFlight),

            .run { [accountID] send in
                do {
                    let values = try await transactionClient.weeklySpending(accountID, 7)
                    await send(.weeklySpendingComputed(values))
                } catch {
                    await send(.sectionFailed(.hero, String(localized: "dashboard_section_load_failed", bundle: .main)))
                }
            }
            .cancellable(id: CancelID.weeklySpending, cancelInFlight: cancelInFlight),

            statsEffect(cancelInFlight: cancelInFlight),

            insightsEffect(cancelInFlight: cancelInFlight)
        )
    }

    /// Loads the AI insight carousel entries.
    private func insightsEffect(cancelInFlight: Bool) -> Effect<Action> {
        .run { send in
            do {
                let summary = SpendingSummary(monthTotal: 0, weekTotal: 0)
                let list = try await aiUseCase.generateInsights(summary)
                await send(.insightsLoaded(list))
            } catch {
                await send(.sectionFailed(.insight, String(localized: "dashboard_section_load_failed", bundle: .main)))
            }
        }
        .cancellable(id: CancelID.insights, cancelInFlight: cancelInFlight)
    }

    /// Loads `StatsSnapshot` and routes success/failure into the
    /// stats section phase machine.
    private func statsEffect(cancelInFlight: Bool) -> Effect<Action> {
        .run { send in
            do {
                let snapshot = try await transactionClient.statsSnapshot()
                await send(.statsComputed(
                    today: snapshot.today,
                    week: snapshot.week,
                    savings: snapshot.savingsPercentage
                ))
            } catch {
                await send(.sectionFailed(.stats, String(localized: "dashboard_section_load_failed", bundle: .main)))
            }
        }
        .cancellable(id: CancelID.stats, cancelInFlight: cancelInFlight)
    }
}

extension DashboardFeature.Destination.State: Equatable {}
extension DashboardFeature.Destination.Action: Equatable {}
