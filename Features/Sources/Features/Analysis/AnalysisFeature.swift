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
        public enum Period: String, Equatable, CaseIterable, Identifiable, Sendable {
            case week
            case month
            case year

            public var id: Self { self }

            var displayName: String {
                switch self {
                case .week: return String(localized: "analysis_period_week")
                case .month: return String(localized: "analysis_period_month")
                case .year: return String(localized: "analysis_period_year")
                }
            }
        }

        public var selectedPeriod: Period = .month
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

        public var hasData: Bool {
            summary != nil
        }

        public init(selectedPeriod: Period = .month, selectedAccountId: Account.ID? = nil) {
            self.selectedPeriod = selectedPeriod
            self.selectedAccountId = selectedAccountId
        }
    }

    public enum Action: Sendable, BindableAction, Equatable {
        case binding(BindingAction<State>)
        case task
        case accountsLoaded([Account])
        case accountSelected(Account.ID?)
        case periodChanged(State.Period)
        case loadData
        case loadedData(TaskResult<AnalysisData?>)
        case budgetMetricsLoaded([BudgetGaugeMetrics])
        case dismissInsight
        case categoryTapped(CategoryProportion)
        case categoryTransactionsLoaded(categoryName: String, [Transaction])
        case categoryDrilldownDismissed
        case aiAssistant(AIAssistantFeature.Action)
    }

    public struct AnalysisData: Equatable, Sendable {
        let summary: FinancialSummary
        let categoryProportions: [CategoryProportion]
        let dailyTrends: [DailyTrend]
        let budgetMetrics: [BudgetGaugeMetrics]
        let insight: InsightDetail?
    }

    // MARK: - Dependencies

    @Dependency(\.accountClient) var accountClient
    @Dependency(\.planningClient) var planningClient
    @Dependency(\.transactionClient) var transactionClient
    @Dependency(\.categoryClient) var categoryClient
    @Dependency(\.insightsClient) var insightsClient

    private enum CancelID { case budgets }

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .task:
                return .merge(
                    .run { [accountClient] send in
                        let accounts = (try? await accountClient.fetchActive()) ?? []
                        await send(.accountsLoaded(accounts))
                    },
                    .send(.loadData)
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
                let period = state.selectedPeriod
                let selectedAccountId = state.selectedAccountId
                return .merge(
                    .run { [transactionClient, categoryClient, insightsClient] send in
                        do {
                        let dateRange = Self.dateRange(for: period)
                        let filter = TransactionFilter(
                            accountIds: selectedAccountId.map { Set([$0]) },
                            dateRange: dateRange
                        )
                        let transactions = try await transactionClient.fetch(filter)

                        guard !transactions.isEmpty else {
                            await send(.loadedData(.success(nil)))
                            return
                        }

                        // Summary (exclude transfers)
                        let totalIncome = transactions
                            .filter { $0.type == .income }
                            .reduce(Decimal.zero) { $0 + $1.amount }
                        let totalExpense = transactions
                            .filter { $0.type == .expense }
                            .reduce(Decimal.zero) { $0 + $1.amount }
                        let summary = FinancialSummary(
                            totalIncome: totalIncome,
                            totalExpense: totalExpense
                        )

                        // Category proportions (expenses only)
                        let categories = try await categoryClient.fetchAll()
                        let categoryMap = Dictionary(
                            categories.map { ($0.id, $0.name) },
                            uniquingKeysWith: { first, _ in first }
                        )
                        // Key: categoryId string (or "uncategorized"), Value: (name, amount)
                        var categoryTotals: [String: (name: String, amount: Decimal)] = [:]
                        for txn in transactions where txn.type == .expense {
                            let key: String
                            let name: String
                            if let catId = txn.categoryId {
                                key = catId.uuidString
                                name = categoryMap[catId] ?? String(localized: "analysis_other_category")
                            } else {
                                key = "uncategorized"
                                name = String(localized: "analysis_other_category")
                            }
                            let existing = categoryTotals[key] ?? (name: name, amount: .zero)
                            categoryTotals[key] = (name: existing.name, amount: existing.amount + txn.amount)
                        }
                        let proportions = categoryTotals
                            .sorted { $0.value.amount > $1.value.amount }
                            .map { CategoryProportion(id: $0.key, name: $0.value.name, amount: $0.value.amount) }

                        // Daily trends (expenses only)
                        let cal = Calendar.current
                        var dailyTotals: [Date: Decimal] = [:]
                        for txn in transactions where txn.type == .expense {
                            let day = cal.startOfDay(for: txn.date)
                            dailyTotals[day, default: .zero] += txn.amount
                        }
                        let trends = dailyTotals
                            .sorted { $0.key < $1.key }
                            .map { DailyTrend(date: $0.key, amount: $0.value) }

                        // AI insight
                        var insight: InsightDetail? = nil
                        if insightsClient.isAIAvailable() {
                            let breakdownByName = Dictionary(
                                categoryTotals.values.map { ($0.name, $0.amount) },
                                uniquingKeysWith: { lhs, rhs in lhs + rhs }
                            )
                            let spendingSummary = SpendingSummary(
                                totalIncome: totalIncome,
                                totalExpense: totalExpense,
                                categoryBreakdown: breakdownByName,
                                periodDescription: period.displayName
                            )
                            if let text = try? await insightsClient.generateAIInsight(spendingSummary) {
                                insight = InsightDetail(
                                    title: String(localized: "analysis_ai_insight_title"),
                                    description: text
                                )
                            }
                        }

                        let data = AnalysisData(
                            summary: summary,
                            categoryProportions: proportions,
                            dailyTrends: trends,
                            budgetMetrics: [],
                            insight: insight
                        )
                        await send(.loadedData(.success(data)))
                        } catch {
                            await send(.loadedData(.failure(error)))
                        }
                    },
                    .run { [planningClient, transactionClient, categoryClient] send in
                        let metrics = await Self.computeBudgetMetrics(
                            planningClient: planningClient,
                            transactionClient: transactionClient,
                            categoryClient: categoryClient,
                            accountId: selectedAccountId
                        )
                        await send(.budgetMetricsLoaded(metrics))
                    }
                    .cancellable(id: CancelID.budgets, cancelInFlight: true)
                )

            case .dismissInsight:
                state.insight = nil
                return .none

            case let .categoryTapped(proportion):
                let categoryId = UUID(uuidString: proportion.id)
                let filter = TransactionFilter(
                    categoryIds: categoryId.map { Set([$0]) },
                    types: [.expense],
                    dateRange: Self.dateRange(for: state.selectedPeriod)
                )
                let name = proportion.name
                return .run { [transactionClient] send in
                    let transactions = (try? await transactionClient.fetch(filter)) ?? []
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
                state.isLoading = false
                return .none

            case .aiAssistant:
                return .none
            }
        }
        Scope(state: \.aiAssistant, action: \.aiAssistant) {
            AIAssistantFeature()
        }
    }

    // MARK: - Budget Metrics Computation

    static func computeBudgetMetrics(
        planningClient: PlanningClient,
        transactionClient: TransactionClient,
        categoryClient: CategoryClient,
        accountId: Account.ID? = nil
    ) async -> [BudgetGaugeMetrics] {
        do {
            let activeBudgets = try await planningClient.listActive()
            guard !activeBudgets.isEmpty else { return [] }

            var filteredBudgets = activeBudgets
            if let accountId {
                let accountFilter = TransactionFilter(
                    accountIds: Set([accountId]),
                    types: [.expense]
                )
                if let fetchedTransactions = try? await transactionClient.fetch(accountFilter) {
                    let relevantCategoryIds = Set(fetchedTransactions.compactMap(\.categoryId))
                    filteredBudgets = activeBudgets.filter { budget in
                        guard let catId = budget.categoryId else { return true }
                        return relevantCategoryIds.contains(catId)
                    }
                }
                // If fetch fails, filteredBudgets stays as activeBudgets (no filtering)
            }

            let categories = try await categoryClient.fetchAll()
            let categoryMap = Dictionary(categories.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })

            var metrics: [BudgetGaugeMetrics] = []

            for budget in filteredBudgets {
                let dateRange = currentPeriodRange(for: budget.period)
                let filter = TransactionFilter(
                    categoryIds: budget.categoryId.map { Set([$0]) },
                    types: [.expense],
                    dateRange: dateRange
                )
                let transactions = try await transactionClient.fetch(filter)
                let spent = transactions.reduce(Decimal.zero) { $0 + $1.amount }

                let label: String
                if let catId = budget.categoryId, let catName = categoryMap[catId] {
                    label = catName
                } else {
                    label = budget.name
                }

                metrics.append(BudgetGaugeMetrics(
                    id: budget.id.uuidString,
                    categoryName: label,
                    spentAmount: spent,
                    totalBudget: budget.amount
                ))
            }

            return metrics
        } catch {
            return []
        }
    }

    private static func currentPeriodRange(for period: BudgetPeriod) -> ClosedRange<Date> {
        let cal = Calendar.current
        let now = Date()
        switch period {
        case .weekly:
            let start = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
            return start...now
        case .monthly:
            let start = cal.date(from: cal.dateComponents([.year, .month], from: now)) ?? now
            return start...now
        case .yearly:
            let start = cal.date(from: cal.dateComponents([.year], from: now)) ?? now
            return start...now
        }
    }

    static func dateRange(for period: State.Period) -> ClosedRange<Date> {
        let cal = Calendar.current
        let now = Date()
        switch period {
        case .week:
            let start = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
            return start...now
        case .month:
            let start = cal.date(from: cal.dateComponents([.year, .month], from: now)) ?? now
            return start...now
        case .year:
            let start = cal.date(from: cal.dateComponents([.year], from: now)) ?? now
            return start...now
        }
    }
}
