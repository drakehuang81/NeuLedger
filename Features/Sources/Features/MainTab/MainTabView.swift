import SwiftUI
import ComposableArchitecture

struct MainTabView: View {
    @Bindable var store: StoreOf<MainTabFeature>

    init(store: StoreOf<MainTabFeature>) {
        self.store = store
    }
    
    var body: some View {
        // Our ZStack is mostly conceptually handled by .safeAreaInset which provides the best 
        // natural layout behaviour for underlying ScrollViews (so they don't get cut off).
        // For the sake of matching custom ZStack designs often used with floating bars:
        ZStack {
            // Main content layer
            Group {
                switch store.selectedTab {
                case .home:
                    PlaceholderView(title: "Home", color: .blue)
                case .ledger:
                    PlaceholderView(title: "Ledger", color: .orange)
                case .analysis:
                    PlaceholderView(title: "Analysis", color: .purple)
                case .settings:
                    PlaceholderView(title: "Settings", color: .gray)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // TabBar overlay layer
            VStack {
                Spacer()
                GlobalTabBarView(store: store)
                    .padding(.bottom, 16) // Padding above the absolute bottom/home indicator area
            }
            // Ignore the bottom safe area here, as we manually add bottom padding,
            // or we respect it and add padding from the safe area edge.
        }
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
