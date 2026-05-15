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

    // TODO: 6-month trend requires multi-period transaction fetching that the
    // current reducer does not perform. Keep this `false` until the data layer
    // can supply prior-period totals; the card is hidden in the meantime.
    private let hasMonthlyTrendData: Bool = false

    public var body: some View {
        ZStack {
            WarmGradientBackground(variant: .top)

            ScrollView {
                LazyVStack(spacing: 16) {
                    AnalysisTopBar(store: store)

                    if store.isLoading {
                        loadingContent
                    } else if !store.hasData {
                        EmptyStateView(
                            icon: "chart.pie.fill",
                            title: String(localized: "analysis_no_data_title"),
                            description: String(localized: "analysis_no_data_desc")
                        )
                        .padding(.top, 60)
                    } else {
                        loadedContent
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 100)
            }
            .scrollIndicators(.hidden)
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await store.send(.task).finish()
        }
        .sheet(
            item: Binding(
                get: { store.categoryDrilldown },
                set: { newValue in
                    if newValue == nil {
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
    }

    // MARK: - Phases

    private var loadingContent: some View {
        VStack(spacing: 16) {
            KPIStrip(summary: nil)
                .skeleton(when: true)
            DailyBarsCard(trends: [])
                .skeleton(when: true)
            CategoryDonutCard(proportions: []) { _ in }
                .skeleton(when: true)
        }
    }

    private var loadedContent: some View {
        VStack(spacing: 16) {
            KPIStrip(summary: store.summary)

            DailyBarsCard(trends: store.dailyTrends)

            if hasMonthlyTrendData {
                MonthlyTrendCard(monthlyTotals: [])
            }

            if !store.categoryProportions.isEmpty {
                CategoryDonutCard(
                    proportions: store.categoryProportions
                ) { proportion in
                    store.send(.categoryTapped(proportion))
                }
            }

            if !store.budgetMetrics.isEmpty {
                GlassContainer(cornerRadius: 16, padding: 14) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(String(localized: "analysis_budget_progress"))
                            .font(.system(size: 9, weight: .medium).monospacedDigit())
                            .textCase(.uppercase)
                            .tracking(1.2)
                            .foregroundStyle(Color.Design.textSecondary)
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

            AIDock(insight: store.insight)

            if store.aiAssistant.isAvailable {
                AIAssistantCardView(
                    store: store.scope(state: \.aiAssistant, action: \.aiAssistant)
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
                    Text(txn.amount.twdFormatted)
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
