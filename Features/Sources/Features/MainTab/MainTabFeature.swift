import Foundation
import ComposableArchitecture
import Domain

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
        var dashboard = DashboardFeature.State()
        var analysis = AnalysisFeature.State()
        var settings = SettingsFeature.State()
    }

    // MARK: - Action
    enum Action: Equatable {
        case tabSelected(Tab)
        case contextActionTapped // Global context action, e.g., search or add
        case innerTabPlaceholderAction // Placeholder action for inner tabs
        case dashboard(DashboardFeature.Action)
        case analysis(AnalysisFeature.Action)
        case settings(SettingsFeature.Action)
    }
    
    // MARK: - Body
    var body: some ReducerOf<Self> {
        Scope(state: \.dashboard, action: \.dashboard) {
            DashboardFeature()
        }
        Scope(state: \.analysis, action: \.analysis) {
            AnalysisFeature()
        }
        Scope(state: \.settings, action: \.settings) {
            SettingsFeature()
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

            // Task 4.2: Intercept DashboardFeature.Action.delegate actions
            case .dashboard(.delegate(.seeAllTransactionsTapped)):
                // Navigate to the analysis/transactions tab
                state.selectedTab = .analysis
                return .none

            case .dashboard(.delegate(.accountTapped)):
                // Navigate to the analysis tab for account details
                state.selectedTab = .analysis
                return .none

            case .dashboard(.delegate(.transactionTapped)):
                // Could navigate to transaction details — for now stay on dashboard
                return .none
                
            case .dashboard:
                return .none

            case .analysis:
                return .none

            case .settings(.delegate(.navigateToAccounts)):
                return .none

            case .settings(.delegate(.navigateToCategories)):
                return .none

            case .settings(.delegate(.navigateToBudgets)):
                return .none

            case .settings(.delegate(.navigateToTags)):
                return .none

            case .settings:
                return .none
            }
        }
    }
}

