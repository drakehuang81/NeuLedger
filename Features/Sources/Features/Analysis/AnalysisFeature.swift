import ComposableArchitecture
import Domain
import Foundation

@Reducer
public struct AnalysisFeature: Sendable {
    public init() {}

    public struct CategoryDrilldownState: Equatable, Sendable, Identifiable {
        public var id: String { categoryName }
        public let categoryName: String
        public let transactions: [Transaction]

        public init(categoryName: String, transactions: [Transaction]) {
            self.categoryName = categoryName
            self.transactions = transactions
        }
    }

    @ObservableState
    public struct State: Equatable, Sendable {
        public var selectedPeriod: BudgetPeriod = .monthly
        public var selectedAccountId: Account.ID? = nil
        public var accounts: [Account] = []
        public var isLoading: Bool = false

        public var summary: FinancialSummary?
        public var categoryProportions: [CategoryProportion] = []
        public var dailyTrends: [DailyTrend] = []
        public var budgetMetrics: [BudgetGaugeMetrics] = []
        public var insight: InsightDetail?
        public var categoryDrilldown: CategoryDrilldownState?
        public var aiAssistant: AIAssistantFeature.State = .init()

        /// 最近一次載入失敗的訊息；重新載入時清空。View 用 `SectionFailureView` 顯示。
        ///
        /// 沒有這個欄位以前，失敗只會把 `isLoading` 放掉，畫面接著落到 `!hasData` 的
        /// 空狀態——等於對使用者說「你沒有任何資料」，而且沒有重試出口。
        public var loadError: String?

        public var hasData: Bool {
            summary != nil
        }

        public init(selectedPeriod: BudgetPeriod = .monthly, selectedAccountId: Account.ID? = nil) {
            self.selectedPeriod = selectedPeriod
            self.selectedAccountId = selectedAccountId
        }
    }

    public enum Action: Sendable, Equatable {
        case task
        case accountsLoaded([Account])
        case accountSelected(Account.ID?)
        case periodChanged(BudgetPeriod)
        case loadData
        case loadedData(TaskResult<AnalysisData?>)
        case budgetMetricsLoaded([BudgetGaugeMetrics])
        case categoryTapped(CategoryProportion)
        case categoryTransactionsLoaded(categoryName: String, [Transaction])
        case categoryDrilldownDismissed
        case aiAssistant(AIAssistantFeature.Action)
    }

    public struct AnalysisData: Equatable, Sendable {
        let summary: FinancialSummary
        let categoryProportions: [CategoryProportion]
        let dailyTrends: [DailyTrend]
        let insight: InsightDetail?
    }

    // MARK: - Dependencies

    @Dependency(\.ledgerClient) var ledger
    @Dependency(\.insightsClient) var insightsClient
    @Dependency(\.date.now) var now
    @Dependency(\.calendar) var calendar

    /// `load` 與 `budgets` 必須是**兩個**不同的 id：共用會讓 `.merge` 出去的兩條 effect
    /// 在啟動時互相取消，最後只剩其中一條跑完。
    private enum CancelID { case load, budgets }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                return .merge(
                    .run { [ledger] send in
                        let accounts = (try? await ledger.listActiveAccounts()) ?? []
                        await send(.accountsLoaded(accounts))
                    },
                    .send(.loadData),
                    .send(.aiAssistant(.task))
                )

            case let .accountsLoaded(accounts):
                state.accounts = accounts
                return .none

            case let .accountSelected(id):
                state.selectedAccountId = id
                return .send(.loadData)

            case let .periodChanged(period):
                state.selectedPeriod = period
                return .send(.loadData)

            case .loadData:
                state.isLoading = true
                state.loadError = nil
                let interval = state.selectedPeriod.dateInterval(containing: now, calendar: calendar)
                let periodName = state.selectedPeriod.analysisLabel
                let selectedAccountId = state.selectedAccountId
                return .merge(
                    .run { [insightsClient] send in
                        do {
                            async let summaryTask = insightsClient.financialSummary(interval, selectedAccountId)
                            async let proportionsTask = insightsClient.categoryProportions(interval, selectedAccountId)
                            async let trendsTask = insightsClient.dailyBars(interval, selectedAccountId)
                            let (summary, proportions, trends) = try await (summaryTask, proportionsTask, trendsTask)

                            // 收入與支出皆為 0 視為空期間（只有轉帳也算空）。
                            guard summary.totalIncome > 0 || summary.totalExpense > 0 else {
                                await send(.loadedData(.success(nil)))
                                return
                            }

                            var insight: InsightDetail? = nil
                            if insightsClient.isAIAvailable() {
                                let breakdown = Dictionary(
                                    proportions.map { ($0.name, $0.amount) },
                                    uniquingKeysWith: { $0 + $1 }
                                )
                                let spendingSummary = SpendingSummary(
                                    totalIncome: summary.totalIncome,
                                    totalExpense: summary.totalExpense,
                                    categoryBreakdown: breakdown,
                                    periodDescription: periodName
                                )
                                if let text = try? await insightsClient.generateAIInsight(spendingSummary) {
                                    insight = InsightDetail(
                                        title: String(localized: "analysis_ai_insight_title", bundle: .main),
                                        description: text
                                    )
                                }
                            }

                            await send(.loadedData(.success(AnalysisData(
                                summary: summary,
                                categoryProportions: proportions,
                                dailyTrends: trends,
                                insight: insight
                            ))))
                        } catch {
                            // 被 `CancelID.load` 的 cancelInFlight 取消**不是**載入失敗。
                            // 照送失敗會讓連續切期間變成：接手的 effect 已經寫好新資料，
                            // 遲到的取消錯誤再把錯誤橫幅蓋上去——使用者在正確的數字上看到「無法載入」。
                            guard !(error is CancellationError) else { return }
                            await send(.loadedData(.failure(error)))
                        }
                    }
                    .cancellable(id: CancelID.load, cancelInFlight: true),
                    .run { [insightsClient] send in
                        let metrics = (try? await insightsClient.budgetGauges(selectedAccountId)) ?? []
                        await send(.budgetMetricsLoaded(metrics))
                    }
                    .cancellable(id: CancelID.budgets, cancelInFlight: true)
                )

            case let .categoryTapped(proportion):
                // 未分類桶的 id 是 `CategoryProportion.uncategorizedId`（非 UUID 字串）。
                // 舊版直接 `UUID(uuidString:)` 拿 nil 就讓 `categoryIds` 也是 nil，等於
                // **完全不帶分類篩選**——點圓餅圖的「其他」會列出該期間的每一筆支出，
                // 而 sheet 標題還寫著「其他」。
                //
                // `TransactionFilter` 目前無法表達「categoryId 為 nil」（`categoryIds` 是
                // `Set<Category.ID>?`，空集合的語意是「一筆都不符合」），所以這裡分成兩條路：
                // 已分類桶照常靠 filter；未分類桶取回後在這一層自行收斂。
                let categoryId = UUID(uuidString: proportion.id)
                let isUnassignedBucket = proportion.isUnassigned || categoryId == nil
                let filter = TransactionFilter(
                    categoryIds: categoryId.map { Set([$0]) },
                    accountIds: state.selectedAccountId.map { Set([$0]) },
                    types: [.expense],
                    dateRange: state.selectedPeriod.closedRange(containing: now, calendar: calendar)
                )
                let name = proportion.name
                return .run { [ledger] send in
                    var transactions = ((try? await ledger.listAll(filter)) ?? []).map(\.transaction)
                    if isUnassignedBucket {
                        transactions = transactions.filter { $0.categoryId == nil }
                    }
                    await send(.categoryTransactionsLoaded(categoryName: name, transactions))
                }

            case let .categoryTransactionsLoaded(categoryName, transactions):
                state.categoryDrilldown = CategoryDrilldownState(
                    categoryName: categoryName,
                    transactions: transactions
                )
                return .none

            case .categoryDrilldownDismissed:
                state.categoryDrilldown = nil
                return .none

            case let .budgetMetricsLoaded(metrics):
                state.budgetMetrics = metrics
                return .none

            case let .loadedData(.success(data)):
                state.isLoading = false
                state.loadError = nil
                guard let data else {
                    state.summary = nil
                    state.categoryProportions = []
                    state.dailyTrends = []
                    state.insight = nil
                    return .none
                }
                state.summary = data.summary
                state.categoryProportions = data.categoryProportions
                state.dailyTrends = data.dailyTrends
                state.insight = data.insight
                return .none

            case .loadedData(.failure):
                // 失敗必須外顯。留著上一次的數字（比清成 0 誠實），但畫面改走
                // `SectionFailureView`，使用者才知道看到的是舊資料而不是「沒有資料」。
                state.isLoading = false
                state.loadError = String(localized: "analysis_load_failed", bundle: .main)
                return .none

            case .aiAssistant:
                return .none
            }
        }
        Scope(state: \.aiAssistant, action: \.aiAssistant) {
            AIAssistantFeature()
        }
    }
}
