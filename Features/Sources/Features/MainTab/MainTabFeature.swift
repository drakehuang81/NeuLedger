import Foundation
import ComposableArchitecture

@Reducer
struct MainTabFeature {
    // MARK: - State
    enum Tab: String, CaseIterable, Equatable {
        case dashboard
        case analysis
        case settings
        case search
    }
    
    @ObservableState
    struct State: Equatable {
        var selectedTab: Tab = .dashboard
        var analysis = AnalysisFeature.State()
        // Placeholder for inner tab states if needed later
    }
    
    // MARK: - Action
    enum Action: Equatable {
        case tabSelected(Tab)
        case contextActionTapped // Global context action, e.g., search or add
        case innerTabPlaceholderAction // Placeholder action for inner tabs
        case analysis(AnalysisFeature.Action)
    }
    
    // MARK: - Body
    var body: some ReducerOf<Self> {
        Scope(state: \.analysis, action: \.analysis) {
            AnalysisFeature()
        }
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
                
            case .analysis:
                return .none
            }
        }
    }
}
