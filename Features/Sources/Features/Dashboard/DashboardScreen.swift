import Common
import ComposableArchitecture
import Domain
import SwiftUI

/// The main Dashboard screen — composition root for the B1 Warm Redesign.
///
/// Composes the per-section view stack (Hero balance, stats, transactions,
/// insight, accounts) on top of a warm gradient background. Other sections
/// are skeleton placeholders to be filled in by later slices.
public struct DashboardScreen: View {
    @Bindable var store: StoreOf<DashboardFeature>

    public init(store: StoreOf<DashboardFeature>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            ZStack {
                WarmGradientBackground(variant: .top)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        Group {
                            DashboardTopBar()

                            AccountChipsStrip(store: store)

                            HeroBalanceCard(store: store)
                            StatsRow(store: store)

                        }.padding(.horizontal, 20)

                        InsightCarousel(store: store)

                        TransactionsSection(store: store)
                            .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 120)
                }
                .refreshable {
                    await store.send(.pulledToRefresh).finish()
                }
            }
            .navigationBarHidden(true)
            .task {
                await store.send(.task).finish()
            }
            .sheet(
                item: $store.scope(state: \.addTransaction, action: \.addTransaction)
            ) { addTransactionStore in
                AddTransactionView(store: addTransactionStore)
            }
            .sheet(
                item: $store.scope(state: \.detail, action: \.detail)
            ) { detailStore in
                TransactionDetailView(store: detailStore)
            }
        } destination: { store in
            switch store.case {
            case .analysis(let store):
                AnalysisView(store: store)
            }
        }
    }

}


#Preview("Dashboard") {
    DashboardScreen(
        store: Store(initialState: DashboardFeature.State()) {
            DashboardFeature()
        }
    )
}
