import SwiftUI
import ComposableArchitecture

struct MainTabView: View {
    @Bindable var store: StoreOf<MainTabFeature>

    init(store: StoreOf<MainTabFeature>) {
        self.store = store
    }

    var body: some View {
        TabView(selection: Binding(
            get: { store.selectedTab },
            set: { store.send(.tabSelected($0)) }
        )) {
            Tab("Ledger", systemImage: "chart.pie.fill", value: MainTabFeature.Tab.dashboard) {
                DashboardScreen(store: store.scope(state: \.dashboard, action: \.dashboard))
            }

            Tab("記帳", systemImage: "list.bullet.rectangle.fill", value: MainTabFeature.Tab.transactions) {
                TransactionsView(store: store.scope(state: \.transactions, action: \.transactions))
            }

            Tab("Analysis", systemImage: "chart.bar.fill", value: MainTabFeature.Tab.analysis) {
                AnalysisView(store: store.scope(state: \.analysis, action: \.analysis))
            }

            Tab("Settings", systemImage: "gearshape.fill", value: MainTabFeature.Tab.settings) {
                SettingsView(store: store.scope(state: \.settings, action: \.settings))
            }
        }
        .tabViewStyle(.sidebarAdaptable)
#if os(iOS)
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewBottomAccessory {
            HStack {
                Spacer()
                Button {
                    store.send(.contextActionTapped)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.hierarchical)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 8)
            }
        }
#endif
    }
}

#Preview {
    MainTabView(
        store: Store(initialState: MainTabFeature.State()) {
            MainTabFeature()
        }
    )
}
