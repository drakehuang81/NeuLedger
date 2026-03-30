import Common
import ComposableArchitecture
import Domain
import Foundation
import SwiftUI

public struct AnalysisView: View {
    @Bindable var store: StoreOf<AnalysisFeature>

    public init(store: StoreOf<AnalysisFeature>) {
        self.store = store
    }
    var scrollView: some View {
        ScrollView {
            segmentedView
            if store.isLoading {
                ProgressView()
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
            } else if !store.hasData {
                EmptyStateView(
                    icon: "chart.pie.fill",
                    title: String(localized: "analysis_no_data_title"),
                    description: String(localized: "analysis_no_data_desc")
                )
                .padding(.top, 60)
            } else {
                VStack(spacing: 16) {
                    // 2.4 Integrate SummaryCardView
                    if let summary = store.summary {
                        SummaryCardView(summary: summary)
                    }

                    // 3.3 Add charting sections
                    if !store.categoryProportions.isEmpty {
                        CategoryPieChartView(
                            proportions: store.categoryProportions
                        ) { proportion in
                            store.send(.categoryTapped(proportion))
                        }
                    }

                    TrendBarChartView(
                        trends: store.dailyTrends,
                        dateRange: AnalysisFeature.dateRange(
                            for: store.selectedPeriod
                        )
                    )

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

                    // AI Assistant card — only shown when Foundation Models is available
                    if store.aiAssistant.isAvailable {
                        AIAssistantCardView(
                            store: store.scope(state: \.aiAssistant, action: \.aiAssistant)
                        )
                    }
                }
                .padding(.all, 16)
            }
        }
    }
    var segmentedView: some View {
        Picker(
            "Period",
            selection: Binding(
                get: { store.selectedPeriod },
                set: { store.send(.periodChanged($0)) }
            )
        ) {
            ForEach(AnalysisFeature.State.Period.allCases) {
                period in
                Text(period.displayName).tag(period)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.Design.background)
    }

    public var body: some View {
        scrollView
            .background(Color.Design.background.ignoresSafeArea())
            .navigationTitle(String(localized: "analysis_title"))
            .navigationBarTitleDisplayMode(.large)
            .task {
                await store.send(.task).finish()
            }
            .sheet(
                item: Binding(
                    get: { store.categoryDrilldown },
                    set: {
                        if $0 == nil {
                            store.send(.categoryDrilldownDismissed)
                        }
                    }
                )
            ) { drilldown in
                CategoryTransactionsView(
                    categoryName: drilldown.categoryName,
                    transactions: drilldown.transactions
                )
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !store.accounts.isEmpty {
                        Menu {
                            Button(String(localized: "analysis_all_accounts")) {
                                store.send(.accountSelected(nil))
                            }
                            ForEach(store.accounts) { account in
                                Button(account.name) {
                                    store.send(.accountSelected(account.id))
                                }
                            }
                        } label: {
                            let selectedName = store.selectedAccountId
                                .flatMap { id in store.accounts.first { $0.id == id }?.name }
                            Label(
                                selectedName ?? String(localized: "analysis_all_accounts"),
                                systemImage: "chevron.up.chevron.down"
                            )
                            .font(Font.Design.callout)
                        }
                    }
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
                        Text(
                            txn.note?.isEmpty == false
                                ? txn.note!
                                : String(localized: "analysis_no_note")
                        )
                        .font(Font.Design.body)
                        .foregroundStyle(Color.Design.textPrimary)
                        Text(
                            txn.date.formatted(
                                date: .abbreviated,
                                time: .omitted
                            )
                        )
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
    NavigationStack {
        AnalysisView(
            store: Store(initialState: AnalysisFeature.State()) {
                AnalysisFeature()
            }
        )
    }
}

#Preview("Empty State") {
    NavigationStack {
        AnalysisView(
            store: Store(initialState: AnalysisFeature.State()) {
                AnalysisFeature()
            }
        )
    }
}
