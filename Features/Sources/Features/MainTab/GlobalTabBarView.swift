import SwiftUI
import ComposableArchitecture

struct GlobalTabBarView: View {
    @Bindable var store: StoreOf<MainTabFeature>
    
    // Namespace for matched geometric effect (if we want animated pill sliding in the future,
    // though for now simple background changes are fine)
    @Namespace private var tabSelection
    
    var body: some View {
        HStack(spacing: 12) {
            navCapsule
            contextCapsule
        }
        .padding(.horizontal, 16)
        .frame(height: 60)
    }
    
    // MARK: - Nav Capsule
    private var navCapsule: some View {
        HStack(spacing: 4) {
            ForEach(MainTabFeature.Tab.allCases, id: \.self) { tab in
                Button {
                    store.send(.tabSelected(tab), animation: .spring(response: 0.3, dampingFraction: 0.7))
                } label: {
                    Image(systemName: iconName(for: tab))
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(store.selectedTab == tab ? .primary : .secondary)
                        .frame(width: 44, height: 44)
                        .background {
                            if store.selectedTab == tab {
                                Circle()
                                    .fill(Color(uiColor: .systemBackground))
                                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                                    .matchedGeometryEffect(id: "activeTab", in: tabSelection)
                            }
                        }
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 60)
        .background(.regularMaterial)
        .clipShape(Capsule())
        // Apply shadow to the capsule
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
    }
    
    // MARK: - Context Capsule
    private var contextCapsule: some View {
        Button {
            store.send(.contextActionTapped)
        } label: {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.secondary)
                .frame(width: 52, height: 52)
                .background(.regularMaterial)
                .clipShape(Circle())
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Helpers
    private func iconName(for tab: MainTabFeature.Tab) -> String {
        switch tab {
        case .home:
            return "house.fill"
        case .ledger:
            return "list.bullet.rectangle.portrait.fill"
        case .analysis:
            return "chart.pie.fill"
        case .settings:
            return "gearshape.fill"
        }
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.1).ignoresSafeArea()
        
        VStack {
            Spacer()
            GlobalTabBarView(
                store: Store(initialState: MainTabFeature.State()) {
                    MainTabFeature()
                }
            )
            .padding(.bottom, 20)
        }
    }
}
