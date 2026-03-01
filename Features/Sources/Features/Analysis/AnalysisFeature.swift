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
    }
    
    public struct AnalysisData: Equatable, Sendable {
        let summary: FinancialSummary
        let categoryProportions: [CategoryProportion]
        let dailyTrends: [DailyTrend]
        let budgetMetrics: [BudgetGaugeMetrics]
        let insight: InsightDetail
    }
    
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
                // Simulate loading mock data using dispatch queue or environment
                if state.hasData {
                    return .run { [period = state.selectedPeriod] send in
                        // MOCK DATA implementation
                        try await Task.sleep(for: .seconds(0.3)) // fake delay
                        let mockData = AnalysisFeature.generateMockData(for: period)
                        await send(.loadedData(.success(mockData)))
                    }
                } else {
                    return .none
                }
                
            case let .loadedData(.success(data)):
                state.summary = data.summary
                state.categoryProportions = data.categoryProportions
                state.dailyTrends = data.dailyTrends
                state.budgetMetrics = data.budgetMetrics
                state.insight = data.insight
                return .none
                
            case .loadedData(.failure):
                // Handle error if any
                return .none
            }
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
            budgetMetrics: [
                BudgetGaugeMetrics(categoryName: "交通", spentAmount: 4200, totalBudget: 5000),
                BudgetGaugeMetrics(categoryName: "娛樂", spentAmount: 1800, totalBudget: 3000)
            ],
            insight: InsightDetail(
                title: "💡 AI 週報洞察",
                description: "本週五的支出最高，達 $5,200。主要集中在飲食與交通。建議週末準備便當可節省約 $800。"
            )
        )
    }
}
