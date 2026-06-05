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
        case balances
        case categoryFetch
        case aiInsightFetch
        case weeklySpending
        case stats
        case insights
    }

    // MARK: - State

    @ObservableState
    public struct State: Equatable {
        // ═══ 查詢參數（chip 唯一控制的東西）═══
        public var selectedAccountID: Account.ID? = nil

        // ═══ 查詢結果 —— 每個欄位只有一個寫入 action ═══
        public var accounts: [Account] = []                                  // accountsUpdated
        /// 餘額是全帳本 fold（`ledger.balances()`），recent 20 推導不出來，必須 stored。
        public var accountBalances: [Account.ID: Decimal] = [:]              // accountBalancesComputed
        /// 當前 scope（selectedAccountID）的近期 20 筆，已按日期降冪。
        public var recentTransactions: [Transaction] = []                    // transactionsUpdated
        /// 當前 scope「真正」最早一筆的日期（非 recent 20 的 min）——驅動 sparkline 暖身判斷。
        public var earliestTransactionDate: Date? = nil                      // transactionsUpdated
        public var categoryMap: [Domain.Category.ID: Domain.Category] = [:]  // categoriesLoaded
        public var weeklySpending: [Decimal] = []                            // weeklySpendingComputed

        // AI Insight
        public var aiInsight: String?
        public var isLoadingInsight: Bool = false
        public var lastInsightTransactionCount: Int?

        // Stats（全域數字 —— TODO(stats-follow-up): 連動需 todayStats 增加 accountId 參數）
        public var todaySpending: Decimal = 0
        public var weekSpending: Decimal = 0
        public var savingsPercentage: Double = 0

        // Insight carousel（populated by Slice 7）
        public var insights: [InsightData] = []
        public var insightIndex: Int = 0

        // Loading & UI state
        public var isLoading: Bool = false
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

        // ═══ Computed 衍生 —— 禁止為這些值新增 stored 影子 ═══
        /// Chip 顯示順序（sortOrder 升冪）。
        public var orderedAccounts: [Account] {
            accounts.sorted { $0.sortOrder < $1.sortOrder }
        }
        public var totalBalance: Decimal {
            accountBalances.values.reduce(0, +)
        }
        /// Hero 卡顯示的餘額：選中帳戶的餘額，未選則總額。
        ///
        /// 已知行為：若 `selectedAccountID` 指向的帳戶已被封存（如另一裝置同步），
        /// `balances()` 不會回傳該 key，此處回退顯示總額。stale selection 的清理
        /// 屬帳戶生命週期決策 —— TODO(stats-follow-up) 一併處理。
        public var filteredBalance: Decimal {
            selectedAccountID.flatMap { accountBalances[$0] } ?? totalBalance
        }

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
        case accountBalancesComputed([Account.ID: Decimal])                     // total 參數刪除（改 computed）
        case transactionsUpdated(recent: [Transaction], earliestDate: Date?)    // scope 查詢結果
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

    @Dependency(\.ledgerClient) var ledger
    @Dependency(\.insightsClient) var insightsClient
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
                state.accounts = accounts
                state.accountsPhase = .loaded
                // 餘額一次查回 —— `ledger.balances()` 本就存在，
                // 取代原本手刻的 per-account task group。
                return .run { send in
                    do {
                        let balances = try await ledger.balances()
                        await send(.accountBalancesComputed(balances))
                    } catch {
                        await send(.sectionFailed(.hero, String(localized: "dashboard_section_load_failed", bundle: .main)))
                    }
                }
                .cancellable(id: CancelID.balances, cancelInFlight: true)

            case let .accountBalancesComputed(balances):
                state.accountBalances = balances
                return .none

            case let .transactionsUpdated(recent, earliestDate):
                state.recentTransactions = recent
                state.earliestTransactionDate = earliestDate
                state.transactionsPhase = .loaded
                state.isLoading = false

                // AI insight 失效判斷：比較與寫回（aiInsightResponse.success）
                // 都用 recentTransactions.count —— 同一來源（Bug 3 fix）。
                // 已知限制：等量編輯（筆數不變、金額變）不會觸發重打，
                // 沿用舊行為 —— TODO(insights-follow-up) 一併重新設計。
                if state.lastInsightTransactionCount != recent.count {
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
                    return sparklineEffect(accountID: state.selectedAccountID, cancelInFlight: true)
                case .accounts:
                    state.accountsPhase = .loading
                    return accountsEffect(cancelInFlight: true)
                case .transactions:
                    state.transactionsPhase = .loading
                    return transactionsEffect(accountID: state.selectedAccountID, cancelInFlight: true)
                case .stats:
                    state.statsPhase = .loading
                    return statsEffect(cancelInFlight: true)
                case .insight:
                    state.insightPhase = .loading
                    return insightsEffect(cancelInFlight: true)
                }

            case let .accountChipSelected(accountID):
                state.selectedAccountID = accountID
                state.heroPhase = .loading
                state.transactionsPhase = .loading
                // filteredBalance / 交易列表不需手動重算 —— 前者是 computed，
                // 後者由 scope 查詢寫回。
                // TODO(stats-follow-up): StatsRow 連動 —— `insightsClient.todayStats`
                //   需要 accountId 參數（Domain 介面 + Application 實作變更，另開單）。
                //   屆時在此 merge statsEffect 並將 statsPhase 轉 loading。
                // TODO(insights-follow-up): InsightCarousel 連動 —— generateInsights
                //   實作後帶 selectedAccountID 重查，並重新設計 AI insight 失效策略。
                return .merge(
                    transactionsEffect(accountID: accountID, cancelInFlight: true),
                    sparklineEffect(accountID: accountID, cancelInFlight: true)
                )

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
                guard insightsClient.isAIAvailable() else { return .none }
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

                    let insight = try await insightsClient.generateAIInsight(summary)
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
                return refreshAfterMutation(accountID: state.selectedAccountID)

            case let .addTransaction(.presented(.delegate(.savedRecurringConfirmation(id, newNextDueDate)))):
                return .merge(
                    refreshAfterMutation(accountID: state.selectedAccountID),
                    .send(.delegate(.savedRecurringConfirmation(id, newNextDueDate)))
                )

            case .addTransaction:
                return .none

            case .path:
                return .none

            case .detail(.presented(.delegate(.deleted))),
                 .detail(.presented(.delegate(.updated))):
                return refreshAfterMutation(accountID: state.selectedAccountID)

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

    /// Loads active accounts; routes failure into the accounts section phase.
    private func accountsEffect(cancelInFlight: Bool) -> Effect<Action> {
        .run { send in
            do {
                let accounts = try await ledger.listActiveAccounts()
                await send(.accountsUpdated(accounts))
            } catch {
                await send(.sectionFailed(.accounts, String(localized: "dashboard_section_load_failed", bundle: .main)))
            }
        }
        .cancellable(id: CancelID.accountObservation, cancelInFlight: cancelInFlight)
    }

    /// Per-selection transactions query: fetch the ledger, scope it to the
    /// selected account（雙向：轉出 `accountId` / 轉入 `toAccountId`，與
    /// `ledger.balance` 的雙向語意對齊），sort desc, keep the recent 20.
    ///
    /// Also derives the scope's TRUE earliest date（Bug 4 fix —— 取 recent 20
    /// 的 min 會把「3 天記 20 筆」的活躍使用者誤判成新用戶而藏掉 sparkline）。
    /// 全取後本地過濾是專案慣例（fetchAll + Swift 過濾，瓶頸才下推）。
    private func transactionsEffect(
        accountID: Account.ID?,
        cancelInFlight: Bool
    ) -> Effect<Action> {
        .run { send in
            do {
                let all = try await ledger.listAll(TransactionFilter()).map(\.transaction)
                let scoped = accountID.map { id in
                    all.filter { $0.accountId == id || $0.toAccountId == id }
                } ?? all
                let sorted = scoped.sorted { $0.date > $1.date }
                await send(.transactionsUpdated(
                    recent: Array(sorted.prefix(20)),
                    earliestDate: sorted.last?.date
                ))
            } catch {
                await send(.sectionFailed(.transactions, String(localized: "dashboard_section_load_failed", bundle: .main)))
            }
        }
        .cancellable(id: CancelID.transactionObservation, cancelInFlight: cancelInFlight)
    }

    /// Loads the 7-day expense sparkline for the selected scope.
    private func sparklineEffect(
        accountID: Account.ID?,
        cancelInFlight: Bool
    ) -> Effect<Action> {
        .run { send in
            do {
                let values = try await insightsClient.weeklySparkline(accountID)
                await send(.weeklySpendingComputed(values))
            } catch {
                await send(.sectionFailed(.hero, String(localized: "dashboard_section_load_failed", bundle: .main)))
            }
        }
        .cancellable(id: CancelID.weeklySpending, cancelInFlight: cancelInFlight)
    }

    /// 任何帳本異動（新增 / 編輯 / 刪除交易）後的統一重載：
    /// 帳戶＋餘額、scope 交易、stats、sparkline。
    /// 取代原本在 saved / savedRecurringConfirmation / detail-updated 三處
    /// 重複且無錯誤處理的 inline effect。
    ///
    /// 刻意不含 categories（異動罕見，AddTransaction 流程內分類已存在）與
    /// insights carousel（AI insight 由 `transactionsUpdated` 的 count diff 間接觸發）。
    private func refreshAfterMutation(accountID: Account.ID?) -> Effect<Action> {
        .merge(
            accountsEffect(cancelInFlight: true),
            transactionsEffect(accountID: accountID, cancelInFlight: true),
            statsEffect(cancelInFlight: true),
            sparklineEffect(accountID: accountID, cancelInFlight: true)
        )
    }

    /// Loads all dashboard sections concurrently. Each loader has its own
    /// do/catch translating failures into `.sectionFailed(...)` (or, for
    /// categories, swallowing them silently — categories only feed styling).
    private func loadAllSections(
        accountID: Account.ID?,
        cancelInFlight: Bool
    ) -> Effect<Action> {
        .merge(
            accountsEffect(cancelInFlight: cancelInFlight),
            transactionsEffect(accountID: accountID, cancelInFlight: cancelInFlight),
            .run { send in
                do {
                    let categories = try await ledger.listCategories(nil)
                    await send(.categoriesLoaded(categories))
                } catch {
                    // Categories feed UI styling; failure leaves the cached map intact.
                }
            }
            .cancellable(id: CancelID.categoryFetch, cancelInFlight: cancelInFlight),
            sparklineEffect(accountID: accountID, cancelInFlight: cancelInFlight),
            statsEffect(cancelInFlight: cancelInFlight),
            insightsEffect(cancelInFlight: cancelInFlight)
        )
    }

    /// Loads the AI insight carousel entries.
    private func insightsEffect(cancelInFlight: Bool) -> Effect<Action> {
        .run { send in
            do {
                let summary = SpendingSummary(monthTotal: 0, weekTotal: 0)
                let list = try await insightsClient.generateInsights(summary)
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
        .run { [now] send in
            do {
                let snapshot = try await insightsClient.todayStats(now)
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
