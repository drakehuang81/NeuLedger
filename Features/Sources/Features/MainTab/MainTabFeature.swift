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

        // Recurring transaction confirmation routing
        var pendingRecurringConfirmationId: RecurringTransaction.ID? = nil

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

        // Recurring transaction confirmation routing
        case pendingRecurringConfirmationReceived(RecurringTransaction.ID)
        case recurringTemplateFetched(RecurringTransaction)

        case accessory(AccessoryBarFeature.Action)
        case dashboard(DashboardFeature.Action)
        case transactions(TransactionsFeature.Action)
        case settings(SettingsFeature.Action)
    }

    // MARK: - Dependencies
    @Dependency(\.userSettingsRepository) var userSettingsRepository
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
                return .run { send in
                    // Forward to the accessory bar's own load (availability + mode) when MainTabView appears,
                    // so it runs regardless of whether the accessory is currently visible.
                    await send(.accessory(.task))
                    await withTaskGroup(of: Void.self) { group in
                        group.addTask {
                            let showAccessoryBar = userSettingsRepository.bool(.showAccessoryBar)
                            await send(.accessoryBarVisibilityLoaded(showAccessoryBar))
                        }
                        // Subscribe to recurring notification taps
                        group.addTask {
                            for await recurringId in notificationAdapter.pendingConfirmations() {
                                await send(.pendingRecurringConfirmationReceived(recurringId))
                            }
                        }
                    }
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

            // MARK: Recurring
            case let .pendingRecurringConfirmationReceived(id):
                return .run { send in
                    do {
                        let all = try await recurringTransactionClient.fetchAll()
                        guard let template = all.first(where: { $0.id == id }) else { return }
                        await send(.recurringTemplateFetched(template))
                    } catch {
                        // silently ignore — template may have been deleted
                    }
                }

            case let .recurringTemplateFetched(template):
                state.pendingRecurringConfirmationId = template.id
                state.dashboard.addTransaction = AddTransactionFeature.State(
                    mode: .addRecurringConfirmation(template)
                )
                state.selectedTab = .dashboard
                return .none

            // MARK: Child delegates
            case .dashboard(.delegate(.seeAllTransactionsTapped)):
                state.selectedTab = .transactions
                return .none

            case let .dashboard(.delegate(.savedRecurringConfirmation(id, newNextDueDate))):
                state.pendingRecurringConfirmationId = nil
                return .run { send in
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
