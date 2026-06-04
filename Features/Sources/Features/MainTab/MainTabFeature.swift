import Foundation
import ComposableArchitecture
import Domain

@Reducer
struct MainTabFeature {
    // MARK: - State
    enum Tab: String, CaseIterable, Equatable {
        case dashboard
        case settings
        case transactions
    }

    @ObservableState
    struct State: Equatable {
        var selectedTab: Tab = .dashboard
        var dashboard = DashboardFeature.State()
        var transactions = TransactionsFeature.State()
        var settings = SettingsFeature.State()

        // Floating accessory bar (AI input / quick-add)
        var accessory = AccessoryBarFeature.State()

        // Accessory bar visibility — depends on tab + child nav, so it stays here.
        var showAccessoryBar: Bool = true

        var isAccessoryVisible: Bool {
            guard showAccessoryBar else { return false }
            switch selectedTab {
            case .settings:     return settings.path.isEmpty
            case .dashboard:    return dashboard.path.isEmpty
            case .transactions: return true
            }
        }
    }

    // MARK: - Action
    enum Action: Equatable {
        case tabSelected(Tab)

        // Lifecycle
        case task
        case accessoryBarVisibilityLoaded(Bool)

        case accessory(AccessoryBarFeature.Action)
        case dashboard(DashboardFeature.Action)
        case transactions(TransactionsFeature.Action)
        case settings(SettingsFeature.Action)
    }

    // MARK: - Dependencies
    @Dependency(\.platformClient) var platformClient
    @Dependency(\.notificationAdapter) var notificationAdapter
    @Dependency(\.recurringTransactionClient) var recurringTransactionClient

    private enum CancelID {
        case task
    }

    // MARK: - Body
    var body: some ReducerOf<Self> {
        Scope(state: \.accessory, action: \.accessory) {
            AccessoryBarFeature()
        }
        Scope(state: \.dashboard, action: \.dashboard) {
            DashboardFeature()
        }
        Scope(state: \.transactions, action: \.transactions) {
            TransactionsFeature()
        }
        Scope(state: \.settings, action: \.settings) {
            SettingsFeature()
        }
        Reduce { state, action in
            switch action {
            case .task:
                // Forward to the accessory bar's own load (availability + mode) when MainTabView appears,
                // so it runs regardless of whether the accessory is currently visible.
                return .run { send in
                    await send(.accessory(.task))
                    let showAccessoryBar = platformClient.showAccessoryBar()
                    await send(.accessoryBarVisibilityLoaded(showAccessoryBar))
                }
                .cancellable(id: CancelID.task)

            case let .accessoryBarVisibilityLoaded(visible):
                state.showAccessoryBar = visible
                return .none

            case let .tabSelected(tab):
                state.selectedTab = tab
                return .none

            // MARK: Accessory routing (depends on selectedTab — a tab-shell concern)
            case .accessory(.delegate(.contextActionRequested)):
                switch state.selectedTab {
                case .transactions:
                    return .send(.transactions(.contextActionTapped))
                default:
                    return .send(.dashboard(.addTransactionButtonTapped))
                }

            case let .accessory(.delegate(.transactionExtracted(extracted))):
                switch state.selectedTab {
                case .transactions:
                    return .send(.transactions(.addTransactionWithPrefilledData(extracted)))
                default:
                    return .send(.dashboard(.addTransactionWithPrefilledData(extracted)))
                }

            case .accessory:
                return .none

            // MARK: Child delegates
            case .dashboard(.delegate(.seeAllTransactionsTapped)):
                state.selectedTab = .transactions
                return .none

            case let .dashboard(.delegate(.savedRecurringConfirmation(id, newNextDueDate))):
                return .run { _ in
                    do {
                        let all = try await recurringTransactionClient.fetchAll()
                        if var template = all.first(where: { $0.id == id }) {
                            template.nextDueDate = newNextDueDate
                            try await recurringTransactionClient.update(template)
                            try await notificationAdapter.scheduleRecurringReminder(
                                template.id,
                                newNextDueDate,
                                String(localized: "recurring_transaction_notification_title"),
                                String(localized: "recurring_transaction_notification_body")
                            )
                        }
                    } catch {
                        // silently ignore
                    }
                }

            case .dashboard:
                return .none

            case .transactions:
                return .none

            case let .settings(.delegate(.accessoryBarVisibilityChanged(visible))):
                state.showAccessoryBar = visible
                return .none

            case .settings:
                return .none
            }
        }
    }
}
