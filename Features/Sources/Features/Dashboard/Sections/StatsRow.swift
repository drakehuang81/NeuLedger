import SwiftUI
import ComposableArchitecture
import Common

/// The Dashboard stats row — three pills for today's spending,
/// this week's spending, and savings percentage.
struct StatsRow: View {
    let store: StoreOf<DashboardFeature>

    var body: some View {
        switch store.statsPhase {
        case .idle, .loading:
            content.skeleton(when: true)
        case .loaded:
            content
        case let .failed(message):
            GlassContainer(cornerRadius: 16, padding: 12) {
                SectionFailureView(message: message) {
                    store.send(.retrySection(.stats))
                }
            }
        }
    }

    private var content: some View {
        HStack(spacing: 10) {
            StatPill(
                label: "stat_today",
                value: store.todaySpending.twdFormatted
            )
            StatPill(
                label: "stat_week",
                value: store.weekSpending.twdFormatted,
                valueColor: Color.Design.expenseRed
            )
            StatPill(
                label: "stat_saved",
                value: String(format: "%.0f%%", store.savingsPercentage * 100),
                valueColor: Color.Design.incomeGreen
            )
        }
    }
}
