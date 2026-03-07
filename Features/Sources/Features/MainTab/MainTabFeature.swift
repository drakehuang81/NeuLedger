import Foundation
import ComposableArchitecture
import Domain

@Reducer
struct MainTabFeature {
    // MARK: - State
    enum Tab: String, CaseIterable, Equatable {
        case dashboard
        case transactions
        case analysis
        case settings
    }

    @ObservableState
    struct State: Equatable {
        var selectedTab: Tab = .dashboard
        var dashboard = DashboardFeature.State()
        var transactions = TransactionsFeature.State()
        var analysis = AnalysisFeature.State()
        var settings = SettingsFeature.State()
    }

    // MARK: - Action
    enum Action: Equatable {
        case tabSelected(Tab)
        case contextActionTapped
        case dashboard(DashboardFeature.Action)
        case transactions(TransactionsFeature.Action)
        case analysis(AnalysisFeature.Action)
        case settings(SettingsFeature.Action)
    }

    // MARK: - Body
    var body: some ReducerOf<Self> {
        Scope(state: \.dashboard, action: \.dashboard) {
            DashboardFeature()
        }
        Scope(state: \.transactions, action: \.transactions) {
            TransactionsFeature()
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
                switch state.selectedTab {
                case .transactions:
                    return .send(.transactions(.contextActionTapped))
                default:
                    return .send(.dashboard(.addTransactionButtonTapped))
                }

            case .dashboard(.delegate(.seeAllTransactionsTapped)):
                state.selectedTab = .transactions
                return .none

            case .dashboard(.delegate(.accountTapped)):
                state.selectedTab = .analysis
                return .none

            case .dashboard(.delegate(.transactionTapped)):
                return .none

            case .dashboard:
                return .none

            case .transactions:
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
