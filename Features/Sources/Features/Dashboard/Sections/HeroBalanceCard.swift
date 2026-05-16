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
                .animation(.spring(duration: 0.5), value: store.filteredBalance)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            MiniSparkline(
                values: store.weeklySpending,
                minimumColumns: 7
            )
            .frame(height: 40)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Previews

private func heroPreviewState(
    phase: DashboardFeature.SectionPhase,
    balance: Decimal,
    weekly: [Decimal] = []
) -> DashboardFeature.State {
    var state = DashboardFeature.State()
    state.heroPhase = phase
    state.filteredBalance = balance
    state.weeklySpending = weekly
    return state
}

@MainActor private func heroPreviewStore(
    _ state: DashboardFeature.State
) -> StoreOf<DashboardFeature> {
    Store(initialState: state) { DashboardFeature() }
}

private struct HeroPreviewWrapper: View {
    let title: String
    let store: StoreOf<DashboardFeature>

    var body: some View {
        ZStack {
            WarmGradientBackground(variant: .top)
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .textCase(.uppercase)
                    .tracking(1)
                    .foregroundStyle(.secondary)
                HeroBalanceCard(store: store)
            }
            .padding(20)
        }
    }
}

#Preview("Loaded — Positive") {
    HeroPreviewWrapper(
        title: "Loaded · Positive",
        store: heroPreviewStore(
            heroPreviewState(
                phase: .loaded,
                balance: Decimal(125_400),
                weekly: [Decimal(320), 540, 280, 720, 410, 880, 510]
            )
        )
    )
}

#Preview("Loaded — Negative") {
    HeroPreviewWrapper(
        title: "Loaded · Negative",
        store: heroPreviewStore(
            heroPreviewState(
                phase: .loaded,
                balance: Decimal(-8_750),
                weekly: [Decimal(1_200), 980, 1_540, 870, 620, 1_320, 1_100]
            )
        )
    )
}

#Preview("Loaded — Empty Sparkline") {
    HeroPreviewWrapper(
        title: "Loaded · No weekly data",
        store: heroPreviewStore(
            heroPreviewState(
                phase: .loaded,
                balance: Decimal(42_000)
            )
        )
    )
}

#Preview("Loading Skeleton") {
    HeroPreviewWrapper(
        title: "Loading",
        store: heroPreviewStore(
            heroPreviewState(
                phase: .loading,
                balance: Decimal(0)
            )
        )
    )
}

#Preview("Failed") {
    HeroPreviewWrapper(
        title: "Failed",
        store: heroPreviewStore(
            heroPreviewState(
                phase: .failed("Unable to load balance"),
                balance: Decimal(0)
            )
        )
    )
}
