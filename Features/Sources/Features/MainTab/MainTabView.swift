import Common
import ComposableArchitecture
import SwiftUI

struct MainTabView: View {
    @Bindable var store: StoreOf<MainTabFeature>

    init(store: StoreOf<MainTabFeature>) {
        self.store = store
    }

    @ViewBuilder
    var body: some View {
        if #available(iOS 26.1, *) {
            tabViewBase
                .tabViewBottomAccessory(isEnabled: store.isAccessoryVisible) {
                    AccessoryView(store: store)
                }
        } else {
            tabViewBase
                .tabViewBottomAccessory {
                    if store.isAccessoryVisible {
                        AccessoryView(store: store)
                    }
                }
        }
    }


    private var tabViewBase: some View {
        TabView(selection: Binding(
            get: { store.selectedTab },
            set: { store.send(.tabSelected($0)) }
        )) {
            Tab("Ledger", systemImage: "chart.pie.fill", value: MainTabFeature.Tab.dashboard) {
                DashboardScreen(store: store.scope(state: \.dashboard, action: \.dashboard))
            }
            Tab("Settings", systemImage: "gearshape.fill", value: MainTabFeature.Tab.settings) {
                SettingsView(store: store.scope(state: \.settings, action: \.settings))
            }
            Tab(value: MainTabFeature.Tab.transactions, role: .search) {
                TransactionsView(store: store.scope(state: \.transactions, action: \.transactions))
            }
        }
        .task {
            await store.send(.task).finish()
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .tint(Color.Design.accentOrange)
    }
}

#Preview {
    MainTabView(
        store: Store(initialState: MainTabFeature.State()) {
            MainTabFeature()
        }
    )
}
