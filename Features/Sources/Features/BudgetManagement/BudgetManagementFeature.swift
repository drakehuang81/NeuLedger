import ComposableArchitecture
import Domain
import Foundation

@Reducer
public struct BudgetManagementFeature: Sendable {
    public init() {}

    // MARK: - State

    @ObservableState
    public struct State: Equatable {
        public var budgets: [Budget] = []
        public var isLoading: Bool = false
        public var loadError: String? = nil
        public var actionError: String? = nil

        @Presents public var addEdit: BudgetFormFeature.State?
        @Presents public var alert: AlertState<Action.Alert>?

        public init() {}
    }

    // MARK: - Action

    public enum Action: Sendable, Equatable {
        case task
        case budgetsLoaded([Budget])
        case loadFailed(String)
        case actionFailed(String)
        case addButtonTapped
        case budgetTapped(Budget)
        case deleteRequested(Budget.ID)

        case addEdit(PresentationAction<BudgetFormFeature.Action>)
        case alert(PresentationAction<Alert>)

        @CasePathable
        public enum Alert: Sendable, Equatable {
            case deleteConfirmed(Budget.ID)
        }
    }

    // MARK: - Dependencies

    @Dependency(\.planningClient) var planningClient

    private enum CancelID { case task }

    // MARK: - Body

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                state.isLoading = true
                return .run { send in
                    let budgets = try await planningClient.listAll()
                    await send(.budgetsLoaded(budgets))
                } catch: { error, send in
                    await send(.loadFailed(error.localizedDescription))
                }
                .cancellable(id: CancelID.task)

            case let .budgetsLoaded(budgets):
                state.loadError = nil
                state.actionError = nil
                state.isLoading = false
                state.budgets = budgets
                return .none

            case let .loadFailed(message):
                state.isLoading = false
                state.loadError = message
                return .none

            case let .actionFailed(message):
                state.actionError = message
                return .none

            case .addButtonTapped:
                state.addEdit = BudgetFormFeature.State(mode: .add)
                return .none

            case let .budgetTapped(budget):
                state.addEdit = BudgetFormFeature.State(mode: .edit(budget))
                return .none

            case let .deleteRequested(id):
                state.alert = AlertState {
                    TextState(String(localized: "alert_delete_budget"))
                } actions: {
                    ButtonState(role: .destructive, action: .deleteConfirmed(id)) {
                        TextState(String(localized: "common_delete"))
                    }
                    ButtonState(role: .cancel) {
                        TextState(String(localized: "common_cancel"))
                    }
                } message: {
                    TextState(String(localized: "alert_delete_budget_message"))
                }
                return .none

            case let .alert(.presented(.deleteConfirmed(id))):
                return .run { send in
                    try await planningClient.delete(id)
                    let budgets = try await planningClient.listAll()
                    await send(.budgetsLoaded(budgets))
                } catch: { error, send in
                    await send(.actionFailed(error.localizedDescription))
                }

            case .alert:
                return .none

            case .addEdit(.presented(.delegate(.saved))):
                state.addEdit = nil
                return .run { send in
                    let budgets = try await planningClient.listAll()
                    await send(.budgetsLoaded(budgets))
                } catch: { error, send in
                    await send(.actionFailed(error.localizedDescription))
                }

            case .addEdit(.presented(.delegate(.dismissed))):
                state.addEdit = nil
                return .none

            case .addEdit:
                return .none
            }
        }
        .ifLet(\.$addEdit, action: \.addEdit) {
            BudgetFormFeature()
        }
        .ifLet(\.$alert, action: \.alert)
    }
}
