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
                    .font(Font.Design.size12Medium)
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

            sparklineSlot
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var sparklineSlot: some View {
        let daysRemaining = daysUntilSparklineReady(
            earliest: store.earliestTransactionDate,
            now: Date()
        )
        if daysRemaining == 0 {
            MiniSparkline(
                values: store.weeklySpending,
                minimumColumns: 7
            )
            .frame(height: 40)
        } else {
            Text(String(
                format: String(localized: "dashboard_sparkline_warmup_hint", bundle: .main),
                daysRemaining
            ))
            .font(Font.Design.size13)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: 40, alignment: .center)
        }
    }
}

func daysUntilSparklineReady(earliest: Date?, now: Date) -> Int {
    guard let earliest else { return 7 }
    let calendar = Calendar.current
    let earliestDay = calendar.startOfDay(for: earliest)
    let today = calendar.startOfDay(for: now)
    let elapsed = calendar.dateComponents([.day], from: earliestDay, to: today).day ?? 0
    return max(0, 7 - elapsed)
}

// MARK: - Previews

private func heroPreviewState(
    phase: DashboardFeature.SectionPhase,
    balance: Decimal,
    weekly: [Decimal] = [],
    earliestTransactionDate: Date? = Calendar.current.date(byAdding: .day, value: -30, to: Date())
) -> DashboardFeature.State {
    var state = DashboardFeature.State()
    state.heroPhase = phase
    state.filteredBalance = balance
    state.weeklySpending = weekly
    state.earliestTransactionDate = earliestTransactionDate
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
                    .font(Font.Design.size11Medium)
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

#Preview("Loaded — Warmup (new user)") {
    HeroPreviewWrapper(
        title: "Loaded · Warmup hint",
        store: heroPreviewStore(
            heroPreviewState(
                phase: .loaded,
                balance: Decimal(42_000),
                earliestTransactionDate: Calendar.current.date(byAdding: .day, value: -2, to: Date())
            )
        )
    )
}

#Preview("Loaded — No transactions yet") {
    HeroPreviewWrapper(
        title: "Loaded · No transactions yet",
        store: heroPreviewStore(
            heroPreviewState(
                phase: .loaded,
                balance: Decimal(0),
                earliestTransactionDate: nil
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
