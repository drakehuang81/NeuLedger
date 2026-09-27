import Common
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

        // Stats（全域數字 —— TODO(stats-follow-up): 連動需 todayStats 增加 accountId 參數）
        public var todaySpending: Decimal = 0
        public var weekSpending: Decimal = 0
        public var savingsPercentage: Double = 0

        // Insight carousel（populated by Slice 7）
        public var insights: [InsightData] = []
        public var insightIndex: Int = 0

        // UI state
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

        // User interactions
        case addTransactionButtonTapped
        // Received from MainTabFeature when the TabBar AI input successfully extracts a transaction.
        case addTransactionWithPrefilledData(ExtractedTransaction)
        case seeAllTransactionsTapped
        /// Entry from the "餘額總覽" section header; navigates to Analysis with
        /// the dashboard's currently-selected account filter (nil → portfolio view).
        case analysisShortcutTapped
        case transactionTapped(Transaction.ID)

        // Child features
        case path(StackActionOf<Destination>)
        case addTransaction(PresentationAction<AddTransactionFeature.Action>)
        case detail(PresentationAction<TransactionDetailFeature.Action>)
        case pendingDeleteCommitted

        // Delegation to parent
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Sendable, Equatable {
            case seeAllTransactionsTapped
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
                state.heroPhase = .loading
                state.statsPhase = .loading
                state.transactionsPhase = .loading
                state.insightPhase = .loading
                state.accountsPhase = .loading
                return loadAllSections(
                    accountID: state.selectedAccountID,
                    cancelInFlight: false
                )

            // Task 2.5: Pull-to-refresh — reload data
            case .pulledToRefresh:
                return loadAllSections(
                    accountID: state.selectedAccountID,
                    cancelInFlight: true
                )

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
                // TODO(insights-follow-up): InsightCarousel 連動 —— 洞察的數字來自
                //   `todayStats` + `categoryProportions`，兩者同樣不吃 accountId，
                //   所以卡片目前是跨帳戶合計（R9）。與上面那張單一起解。
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

            // MARK: User interactions

            case .addTransactionButtonTapped:
                state.addTransaction = AddTransactionFeature.State(mode: .add(.expense), date: now)
                return .none

            case let .addTransactionWithPrefilledData(extracted):
                state.addTransaction = AddTransactionFeature.State(mode: .addPrefilled(extracted), date: now)
                return .none

            case .seeAllTransactionsTapped:
                return .send(.delegate(.seeAllTransactionsTapped))

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

            case .addTransaction:
                return .none

            case .path:
                return .none

            case .detail(.presented(.delegate(.deleted))),
                 .detail(.presented(.delegate(.updated))):
                return refreshAfterMutation(accountID: state.selectedAccountID)

            case .detail(.dismiss):
                guard let detail = state.detail, detail.pendingDelete else { return .none }
                // 同 TransactionsFeature：Undo 視窗內關 sheet 由 parent 提交刪除。
                let id = detail.transaction.id
                return .run { send in
                    try await ledger.delete(id)
                    await send(.pendingDeleteCommitted)
                } catch: { _, send in
                    await send(.sectionFailed(.transactions, String(localized: "dashboard_section_load_failed", bundle: .main)))
                }

            case .pendingDeleteCommitted:
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
                    all.filter { $0.involves(account: id) }
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
    /// 帳戶＋餘額、scope 交易、stats、sparkline、insights。
    /// 取代原本在 saved / detail-updated 兩處
    /// 重複且無錯誤處理的 inline effect。
    ///
    /// 刻意不含 categories（異動罕見，AddTransaction 流程內分類已存在）。
    ///
    /// **insights 必須重載。** 在洞察還是寫死假資料的年代這裡刻意排除它（重載
    /// 捏造的數字沒有意義）；洞察改成從帳本算之後那個排除就反轉成缺陷，而且正好
    /// 打在最需要它的人身上：全新使用者讀到空狀態的「記幾筆帳之後，這裡會出現你的
    /// 支出洞察」，照著記了一筆，卡片卻不動。空狀態指示一個動作、做了卻沒反應，
    /// 比它取代掉的假資料更糟。
    private func refreshAfterMutation(accountID: Account.ID?) -> Effect<Action> {
        .merge(
            accountsEffect(cancelInFlight: true),
            transactionsEffect(accountID: accountID, cancelInFlight: true),
            statsEffect(cancelInFlight: true),
            sparklineEffect(accountID: accountID, cancelInFlight: true),
            insightsEffect(cancelInFlight: true)
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

    /// Loads the insight carousel entries.
    ///
    /// 先組出**真實**的 `SpendingSummary` 再交給 `generateInsights`：
    /// - `monthTotal` 是當月 `categoryProportions` 的**全部**加總（含未分類那桶）——
    ///   它是總支出，也正是文案「佔本月支出的」那個百分比的分母。
    /// - top category 取金額最大的**已分類**項目（`isUnassigned == false` + `max(by:)`）。
    ///   不取 `first`：那依賴「這個 endpoint 保證降冪」這個沒有測試的契約。也不比對
    ///   名稱裡的破折號，理由見 `CategoryProportion.isUnassigned`。
    ///   `CategoryProportion` 不帶 `Category.ID`，所以只能拿 `name`。
    /// - `weekTotal` / `savingsPercentage` 來自 `todayStats(now)`，兩者都是
    ///   **原值轉手、不做任何算術** —— `InsightComposer` 用 `savingsPercentage != 0`
    ///   判斷要不要產生儲蓄率卡片，這裡若自行重算就會留下浮點殘渣而冒出一張
    ///   顯示「0%」的卡片。
    ///
    /// R9（刻意的限制）：`todayStats` 與 `categoryProportions` 都不吃 accountId，
    /// 所以這些數字是**跨所有帳戶**的合計，不隨 chip 選擇改變 —— 與畫面上方的
    /// StatsRow 行為一致，見 `:270-275` 既有的 `TODO(stats-follow-up)` /
    /// `TODO(insights-follow-up)`。
    private func insightsEffect(cancelInFlight: Bool) -> Effect<Action> {
        .run { [now] send in
            do {
                // 當月區間一律走 BudgetPeriod 的唯一定義，不自行 `dateInterval(of: .month,...)`。
                let monthRange = BudgetPeriod.monthly.dateInterval(containing: now)
                let proportions = try await insightsClient.categoryProportions(monthRange)
                let snapshot = try await insightsClient.todayStats(now)
                // 未分類那桶不是使用者的分類——它金額最大時，首屏會出現
                // 「「—」花了 NT$3,200，佔本月支出的 42%」，讀起來就是個 bug。
                let topCategory = proportions
                    .filter { !$0.isUnassigned }
                    .max(by: { $0.amount < $1.amount })
                let summary = SpendingSummary(
                    // 加總**全部**（含未分類）：這是總支出，刻意不跟 top category 一起過濾。
                    monthTotal: proportions.reduce(Decimal(0)) { $0 + $1.amount },
                    weekTotal: snapshot.week,
                    topCategoryName: topCategory?.name,
                    topCategoryAmount: topCategory?.amount,
                    savingsPercentage: snapshot.savingsPercentage
                )
                let descriptors = try await insightsClient.generateInsights(summary)
                await send(.insightsLoaded(descriptors.map(Self.insightCard(for:))))
            } catch {
                await send(.sectionFailed(.insight, String(localized: "dashboard_section_load_failed", bundle: .main)))
            }
        }
        .cancellable(id: CancelID.insights, cancelInFlight: cancelInFlight)
    }

    // MARK: - Insight presentation

    /// `InsightDescriptor`（Domain：純數字）→ `InsightData`（畫面用：已本地化）。
    ///
    /// 這個映射只能在 Features 層：承載 `generateInsights` 實作的 `Core` target
    /// 只依賴 `Domain`，碰不到 `Common` 的 `twdFormatted` 也碰不到 main bundle 的
    /// localization（`Features/Package.swift:73-87`）。把繁中字串寫死在 Application
    /// 層正是 audit B9 的結構性成因。
    ///
    /// `id` 沿用描述子的 `id`，同一批描述子映射出來的 state 才是可預測的
    /// （不在這裡生成新 UUID）。`cta` 一律 `nil` —— CTA 點擊目前是 no-op
    /// （`InsightCarousel.swift`），不放沒有作用的按鈕。
    static func insightCard(for descriptor: InsightDescriptor) -> InsightData {
        switch descriptor.kind {
        case let .topCategory(name, amount, share):
            let percent = percentText(share)
            return InsightData(
                id: descriptor.id,
                title: String(localized: "dashboard_insight_top_category_title", bundle: .main),
                body: String(
                    format: String(localized: "dashboard_insight_top_category_body", bundle: .main),
                    name,
                    amount.twdFormatted,
                    percent
                ),
                metric: percent,
                metricColor: .expense
            )

        case let .savingsRate(rate):
            let percent = percentText(rate)
            return InsightData(
                id: descriptor.id,
                title: String(localized: "dashboard_insight_savings_title", bundle: .main),
                body: String(
                    format: String(localized: "dashboard_insight_savings_body", bundle: .main),
                    percent
                ),
                metric: percent,
                // 現行 `StatsSnapshot.savingsPercentage` 被 kernel 的 `max(0, ...)`
                // 夾住，但描述子型別允許負值，所以照語意分色。
                metricColor: rate >= 0 ? .income : .expense
            )

        case let .weekSpending(amount):
            return InsightData(
                id: descriptor.id,
                title: String(localized: "dashboard_insight_week_title", bundle: .main),
                body: String(
                    format: String(localized: "dashboard_insight_week_body", bundle: .main),
                    amount.twdFormatted
                ),
                // MetricBadge 空間有限 —— badge 用 compact（NT$1.2萬），內文用完整金額。
                metric: amount.twdCompact,
                metricColor: .neutral
            )
        }
    }

    /// 百分比四捨五入到整數位（`CategoryDonutCard.swift:237` / `KPIStrip.swift:24`
    /// 的既有慣例；`Int()` 會截斷，這個 codebase 已選四捨五入）。
    private static func percentText(_ ratio: Double) -> String {
        String(format: "%.0f%%", ratio * 100)
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
