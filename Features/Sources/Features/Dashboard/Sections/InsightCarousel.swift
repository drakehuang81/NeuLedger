import SwiftUI
import ComposableArchitecture
import Common
import Domain

/// The Dashboard AI insight carousel — a swipe-able TabView with PageDots indicator.
struct InsightCarousel: View {
    let store: StoreOf<DashboardFeature>

    var body: some View {
        switch store.insightPhase {
        case .idle, .loading:
            placeholder.skeleton(when: true)
        case .loaded:
            if store.insights.isEmpty {
                placeholder
            } else {
                content
            }
        case let .failed(msg):
            GlassContainer(cornerRadius: 22, padding: 20) {
                SectionFailureView(message: msg) {
                    store.send(.retrySection(.insight))
                }
            }
        }
    }

    private func swiftColor(for c: InsightColor) -> Color {
        switch c {
        case .income:  return Color.Design.incomeGreen
        case .expense: return Color.Design.expenseRed
        case .accent:  return Color.Design.brandPrimary
        case .neutral: return .secondary
        }
    }

    @ViewBuilder
    private var content: some View {
        VStack(spacing: 10) {
            TabView(selection: Binding(
                get: { store.insightIndex },
                set: { store.send(.insightIndexChanged($0)) }
            )) {
                ForEach(Array(store.insights.enumerated()), id: \.element.id) { (idx, item) in
                    InsightCard(
                        title: item.title,
                        body: item.body,
                        metric: item.metric,
                        metricColor: swiftColor(for: item.metricColor),
                        cta: item.cta
                    ) {
                        // CTA tap — no-op for this slice
                    }
                    .padding(.horizontal, 2)
                    .tag(idx)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 150)

            HStack {
                PageDots(count: store.insights.count, active: store.insightIndex)
                Spacer()
            }
        }
    }

    private var placeholder: some View {
        GlassContainer(cornerRadius: 22, padding: 20) {
            VStack(alignment: .leading, spacing: 10) {
                Text("dashboard_insight_loading_title")
                    .font(.system(size: 16, weight: .semibold))
                Text("dashboard_insight_loading_body")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
