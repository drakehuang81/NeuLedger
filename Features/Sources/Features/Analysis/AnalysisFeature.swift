import ComposableArchitecture
import Domain
import Foundation

@Reducer
public struct AnalysisFeature: Sendable {
    public init() {}

    @ObservableState
    public struct State: Equatable {
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
        public var isLoading: Bool = false

        public var summary: FinancialSummary?
        public var categoryProportions: [CategoryProportion] = []
        public var dailyTrends: [DailyTrend] = []
        public var budgetMetrics: [BudgetGaugeMetrics] = []
        public var insight: InsightDetail?

        public var hasData: Bool {
            summary != nil
        }

        public init(selectedPeriod: Period = .month) {
            self.selectedPeriod = selectedPeriod
        }
    }

    public enum Action: Sendable, BindableAction, Equatable {
        case binding(BindingAction<State>)
        case periodChanged(State.Period)
        case loadData
        case loadedData(TaskResult<AnalysisData?>)
        case budgetMetricsLoaded([BudgetGaugeMetrics])
    }

    public struct AnalysisData: Equatable, Sendable {
        let summary: FinancialSummary
        let categoryProportions: [CategoryProportion]
        let dailyTrends: [DailyTrend]
        let budgetMetrics: [BudgetGaugeMetrics]
        let insight: InsightDetail?
    }

    // MARK: - Dependencies

    @Dependency(\.budgetClient) var budgetClient
    @Dependency(\.transactionClient) var transactionClient
    @Dependency(\.categoryClient) var categoryClient
    @Dependency(\.aiServiceClient) var aiServiceClient

    private enum CancelID { case budgets }

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case let .periodChanged(period):
                state.selectedPeriod = period
                return .send(.loadData)

            case .loadData:
                state.isLoading = true
                let period = state.selectedPeriod
                return .merge(
                    .run { [transactionClient, categoryClient, aiServiceClient] send in
                        let dateRange = Self.dateRange(for: period)
                        let filter = TransactionFilter(dateRange: dateRange)
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
                            uniqueKeysWithValues: categories.map { ($0.id, $0.name) }
                        )
                        var categoryTotals: [String: Decimal] = [:]
                        for txn in transactions where txn.type == .expense {
                            let name: String
                            if let catId = txn.categoryId {
                                name = categoryMap[catId] ?? String(localized: "analysis_other_category")
                            } else {
                                name = String(localized: "analysis_other_category")
                            }
                            categoryTotals[name, default: .zero] += txn.amount
                        }
                        let proportions = categoryTotals
                            .sorted { $0.value > $1.value }
                            .map { CategoryProportion(name: $0.key, amount: $0.value) }

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
                        if aiServiceClient.isAvailable() {
                            let spendingSummary = SpendingSummary(
                                totalIncome: totalIncome,
                                totalExpense: totalExpense,
                                categoryBreakdown: categoryTotals,
                                periodDescription: period.displayName
                            )
                            if let text = try? await aiServiceClient.generateInsight(spendingSummary) {
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
                    },
                    .run { [budgetClient, transactionClient, categoryClient] send in
                        let metrics = await Self.computeBudgetMetrics(
                            budgetClient: budgetClient,
                            transactionClient: transactionClient,
                            categoryClient: categoryClient
                        )
                        await send(.budgetMetricsLoaded(metrics))
                    }
                    .cancellable(id: CancelID.budgets, cancelInFlight: true)
                )

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
            }
        }
    }

    // MARK: - Budget Metrics Computation

    static func computeBudgetMetrics(
        budgetClient: BudgetClient,
        transactionClient: TransactionClient,
        categoryClient: CategoryClient
    ) async -> [BudgetGaugeMetrics] {
        do {
            let activeBudgets = try await budgetClient.fetchActive()
            guard !activeBudgets.isEmpty else { return [] }

            let categories = try await categoryClient.fetchAll()
            let categoryMap = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0.name) })

            var metrics: [BudgetGaugeMetrics] = []

            for budget in activeBudgets {
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
