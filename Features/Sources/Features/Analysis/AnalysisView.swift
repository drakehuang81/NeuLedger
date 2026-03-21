import ComposableArchitecture
import SwiftUI
import Domain
import Common
import Foundation

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
                    Picker("Period", selection: Binding(
                        get: { store.selectedPeriod },
                        set: { store.send(.periodChanged($0)) }
                    )) {
                        ForEach(AnalysisFeature.State.Period.allCases) { period in
                            Text(period.displayName).tag(period)
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
                            title: String(localized: "analysis_no_data_title"),
                            description: String(localized: "analysis_no_data_desc")
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
                                    CategoryPieChartView(proportions: store.categoryProportions) { proportion in
                                        store.send(.categoryTapped(proportion))
                                    }
                                }
                                
                                if !store.dailyTrends.isEmpty {
                                    TrendBarChartView(trends: store.dailyTrends)
                                }
                                
                                // 4.3 Stacking BudgetProgressView and AIInsightCardView
                                if !store.budgetMetrics.isEmpty {
                                    GlassContainer(padding: 20) {
                                        VStack(alignment: .leading, spacing: 16) {
                                            Text("analysis_budget_progress")
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
                                        onClose: { store.send(.dismissInsight) }
                                    )
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 80) // for scroll clearance
                        }
                    }
                }
            }
            .navigationTitle(String(localized: "analysis_title"))
            .onAppear {
                store.send(.loadData)
            }
            .sheet(
                item: Binding(
                    get: { store.categoryDrilldown },
                    set: { if $0 == nil { store.send(.categoryDrilldownDismissed) } }
                )
            ) { drilldown in
                CategoryTransactionsView(
                    categoryName: drilldown.categoryName,
                    transactions: drilldown.transactions
                )
            }
        }
    }
}

// MARK: - Category Drill-down Sheet

private struct CategoryTransactionsView: View {
    let categoryName: String
    let transactions: [Domain.Transaction]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(transactions) { txn in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(txn.note?.isEmpty == false ? txn.note! : String(localized: "analysis_no_note"))
                            .font(Font.Design.body)
                            .foregroundStyle(Color.Design.textPrimary)
                        Text(txn.date.formatted(date: .abbreviated, time: .omitted))
                            .font(Font.Design.caption)
                            .foregroundStyle(Color.Design.textSecondary)
                    }
                    Spacer()
                    Text("NT$\(txn.amount as NSDecimalNumber)")
                        .font(Font.Design.amount)
                        .foregroundStyle(Color.Design.expenseRed)
                }
            }
            .navigationTitle(categoryName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common_close")) { dismiss() }
                }
            }
        }
    }
}

#Preview("Data") {
    AnalysisView(
        store: Store(initialState: AnalysisFeature.State()) {
            AnalysisFeature()
        }
    )
}

#Preview("Empty State") {
    AnalysisView(
        store: Store(initialState: AnalysisFeature.State()) {
            AnalysisFeature()
        }
    )
}
