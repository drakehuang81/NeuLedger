import Common
import ComposableArchitecture
import Domain
import SwiftUI

/// Hero balance card for the Dashboard B1 Warm Redesign.
///
/// Renders the (filtered) total balance, a net metric badge, and a 7-day
/// expense sparkline. Skeleton + retry states are driven by `heroPhase`.
struct HeroBalanceCard: View {
    let store: StoreOf<DashboardFeature>

    var body: some View {
        GlassContainer(cornerRadius: 28, padding: 20) {
            switch store.heroPhase {
            case .idle, .loading:
                content.skeleton(when: true)
            case .loaded:
                content
            case let .failed(message):
                SectionFailureView(message: message) {
                    store.send(.retrySection(.hero))
                }
            }
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("dashboard_total_label")
                    .font(.system(size: 12, weight: .medium))
                    .textCase(.uppercase)
                    .tracking(1)
                    .foregroundStyle(.secondary)
                Spacer()
                MetricBadge(
                    text: store.filteredBalance >= 0
                        ? "+" + store.filteredBalance.twdFormatted
                        : store.filteredBalance.twdFormatted,
                    color: store.filteredBalance >= 0
                        ? Color.Design.incomeGreen
                        : Color.Design.expenseRed
                )
            }

            Text(store.filteredBalance.twdFormatted)
                .font(.system(size: 40, weight: .bold).monospacedDigit())
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            MiniSparkline(
                values: store.weeklySpending.isEmpty
                    ? Array(repeating: Decimal(0), count: 7)
                    : store.weeklySpending
            )
            .frame(height: 40)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
