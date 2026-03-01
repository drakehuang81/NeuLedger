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
                PlaceholderView(title: "Ledger", color: .orange)
            }

            Tab("Analysis", systemImage: "chart.bar.fill", value: MainTabFeature.Tab.analysis) {
                AnalysisView(store: store.scope(state: \.analysis, action: \.analysis))
            }

            Tab("Settings", systemImage: "gearshape.fill", value: MainTabFeature.Tab.settings) {
                PlaceholderView(title: "Settings", color: .gray)
            }
            Tab(value: MainTabFeature.Tab.search, role: .search) {
                // TODO: 用搜尋頁面替代
                PlaceholderView(title: "Search", color: .black)
            }
            .hidden(!(store.selectedTab == .search || store.selectedTab == .dashboard))
        }
        .tabViewStyle(.sidebarAdaptable)
#if os(iOS)
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewBottomAccessory {
            // TODO: 到時候會有一個按鈕，可以新增記帳 ＆ AI 
        }
#endif
    }
}

// A simple placeholder to demonstrate inner scrollable areas and safe area management
private struct PlaceholderView: View {
    let title: String
    let color: Color
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text(title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top, 40)
                
                ForEach(0..<20) { i in
                    RoundedRectangle(cornerRadius: 16)
                        .fill(color.opacity(0.2))
                        .frame(height: 100)
                        .overlay(Text("Item \(i)"))
                        .padding(.horizontal)
                }
            }
            // Adding bottom padding to ensure the last item is not permanently covered by the floating tab bar
            .padding(.bottom, 100)
        }
        .background(Color.gray.opacity(0.1).ignoresSafeArea())
    }
}

#Preview {
    MainTabView(
        store: Store(initialState: MainTabFeature.State()) {
            MainTabFeature()
        }
    )
}
