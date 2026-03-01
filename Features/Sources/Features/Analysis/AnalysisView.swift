import ComposableArchitecture
import SwiftUI
import Domain
import Common

public struct AnalysisView: View {
    @Bindable var store: StoreOf<AnalysisFeature>

    public init(store: StoreOf<AnalysisFeature>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color.Design.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // 2.2 Glass-style Segmented Picker
                    // Segmented Picker / Period Selector at the top of the view.
                    Picker("Period", selection: $store.selectedPeriod) {
                        ForEach(AnalysisFeature.State.Period.allCases) { period in
                            Text(period.rawValue).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                    
                    if !store.hasData {
                        Spacer()
                        EmptyStateView(
                            icon: "chart.pie.fill",
                            title: "目前無資料",
                            description: "切換不同時間區間或是新增記帳紀錄來解鎖分析功能。"
                        )
                        Spacer()
                    } else {
                        ScrollView {
                            VStack(spacing: 16) {
                                // 2.4 Integrate SummaryCardView
                                if let summary = store.summary {
                                    SummaryCardView(summary: summary)
                                }
                                
                                // 3.3 Add charting sections
                                if !store.categoryProportions.isEmpty {
                                    CategoryPieChartView(proportions: store.categoryProportions)
                                }
                                
                                if !store.dailyTrends.isEmpty {
                                    TrendBarChartView(trends: store.dailyTrends)
                                }
                                
                                // 4.3 Stacking BudgetProgressView and AIInsightCardView
                                if !store.budgetMetrics.isEmpty {
                                    GlassContainer(padding: 20) {
                                        VStack(alignment: .leading, spacing: 16) {
                                            Text("預算進度")
                                                .font(Font.Design.headline)
                                                .foregroundStyle(Color.Design.textPrimary)
                                            
                                            ForEach(store.budgetMetrics) { metric in
                                                BudgetGauge(
                                                    total: metric.totalBudget,
                                                    used: metric.spentAmount,
                                                    label: metric.categoryName
                                                )
                                            }
                                        }
                                    }
                                }
                                
                                if let insight = store.insight {
                                    InsightCard(
                                        title: insight.title,
                                        body: insight.description,
                                        onClose: nil
                                    )
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 80) // for scroll clearance
                        }
                    }
                }
            }
            .navigationTitle("分析")
            .onAppear {
                store.send(.loadData)
            }
        }
    }
}

#Preview("Data") {
    AnalysisView(
        store: Store(initialState: AnalysisFeature.State(hasData: true)) {
            AnalysisFeature()
        }
    )
}

#Preview("Empty State") {
    AnalysisView(
        store: Store(initialState: AnalysisFeature.State(hasData: false)) {
            AnalysisFeature()
        }
    )
}
