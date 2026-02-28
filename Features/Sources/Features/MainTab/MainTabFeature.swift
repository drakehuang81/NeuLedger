import Foundation
import ComposableArchitecture

@Reducer
struct MainTabFeature {
    // MARK: - State
    enum Tab: String, CaseIterable, Equatable {
        case home
        case ledger
        case analysis
        case settings
    }
    
    @ObservableState
    struct State: Equatable {
        var selectedTab: Tab = .home
        // Placeholder for inner tab states if needed later
    }
    
    // MARK: - Action
    enum Action: Equatable {
        case tabSelected(Tab)
        case contextActionTapped // Global context action, e.g., search or add
        case innerTabPlaceholderAction // Placeholder action for inner tabs
    }
    
    // MARK: - Body
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .tabSelected(tab):
                state.selectedTab = tab
                return .none
                
            case .contextActionTapped:
                // Handle global context action, e.g. open search or add
                print("Context action tapped") // Debug log as confirmed by specs
                return .none
                
            case .innerTabPlaceholderAction:
                return .none
            }
        }
    }
}
