import ComposableArchitecture
import Domain
import Foundation

@Reducer
public struct AnalysisFeature: Sendable {
    public init() {}

    @ObservableState
    public struct State: Equatable {
        public enum Period: String, Equatable, CaseIterable, Identifiable, Sendable {
            case week = "本週"
            case month = "本月"
            case year = "今年"
            public var id: Self { self }
        }

        public var selectedPeriod: Period = .month
        public var hasData: Bool = false

        public var summary: FinancialSummary?
        public var categoryProportions: [CategoryProportion] = []
        public var dailyTrends: [DailyTrend] = []
        public var budgetMetrics: [BudgetGaugeMetrics] = []
        public var insight: InsightDetail?

        public init(
            selectedPeriod: Period = .month,
            hasData: Bool = false
        ) {
            self.selectedPeriod = selectedPeriod
            self.hasData = hasData
        }
    }

    public enum Action: Sendable, BindableAction, Equatable {
        case binding(BindingAction<State>)
        case periodChanged(State.Period)
        case loadData
        case loadedData(TaskResult<AnalysisData>)
        case budgetMetricsLoaded([BudgetGaugeMetrics])
    }

    public struct AnalysisData: Equatable, Sendable {
        let summary: FinancialSummary
        let categoryProportions: [CategoryProportion]
        let dailyTrends: [DailyTrend]
        let budgetMetrics: [BudgetGaugeMetrics]
        let insight: InsightDetail
    }

    // MARK: - Dependencies

    @Dependency(\.budgetClient) var budgetClient
    @Dependency(\.transactionClient) var transactionClient
    @Dependency(\.categoryClient) var categoryClient

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
                let period = state.selectedPeriod
                let hasData = state.hasData

                // Always fetch real budget metrics regardless of hasData
                let budgetEffect = Effect<Action>.run { [budgetClient, transactionClient, categoryClient] send in
                    let metrics = await AnalysisFeature.computeBudgetMetrics(
                        budgetClient: budgetClient,
                        transactionClient: transactionClient,
                        categoryClient: categoryClient
                    )
                    await send(.budgetMetricsLoaded(metrics))
                }
                .cancellable(id: CancelID.budgets, cancelInFlight: true)

                if hasData {
                    return .merge(
                        budgetEffect,
                        .run { [period] send in
                            // MOCK DATA implementation
                            try await Task.sleep(for: .seconds(0.3))
                            let mockData = AnalysisFeature.generateMockData(for: period)
                            await send(.loadedData(.success(mockData)))
                        }
                    )
                } else {
                    return budgetEffect
                }

            case let .budgetMetricsLoaded(metrics):
                state.budgetMetrics = metrics
                return .none

            case let .loadedData(.success(data)):
                state.summary = data.summary
                state.categoryProportions = data.categoryProportions
                state.dailyTrends = data.dailyTrends
                // budgetMetrics is managed by .budgetMetricsLoaded (real data), not mock
                state.insight = data.insight
                return .none

            case .loadedData(.failure):
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

    // Generate mock data according to design files
    static func generateMockData(for period: State.Period) -> AnalysisData {
        let today = Date()
        let cal = Calendar.current
        var daily: [DailyTrend] = []
        for i in 0..<7 {
            let d = cal.date(byAdding: .day, value: -i, to: today)!
            daily.append(DailyTrend(date: d, amount: Decimal(Int.random(in: 100...2000))))
        }

        return AnalysisData(
            summary: FinancialSummary(totalIncome: 12000, totalExpense: 8000),
            categoryProportions: [
                CategoryProportion(name: "飲食", amount: 4500),
                CategoryProportion(name: "交通", amount: 1500),
                CategoryProportion(name: "娛樂", amount: 2000)
            ],
            dailyTrends: daily.reversed(),
            budgetMetrics: [],
            insight: InsightDetail(
                title: "💡 AI 週報洞察",
                description: "本週五的支出最高，達 $5,200。主要集中在飲食與交通。建議週末準備便當可節省約 $800。"
            )
        )
    }
}
