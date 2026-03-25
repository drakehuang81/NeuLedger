import ComposableArchitecture
import Domain
import Foundation

@Reducer
public struct RecurringTransactionManagementFeature: Sendable {
    public init() {}

    @ObservableState
    public struct State: Equatable {
        public var items: [RecurringTransaction] = []
        public var isLoading: Bool = false
        @Presents public var form: RecurringTransactionFormFeature.State?

        public init(items: [RecurringTransaction] = []) { self.items = items }
    }

    public enum Action: Sendable, Equatable {
        case task
        case loaded([RecurringTransaction])
        case addButtonTapped
        case itemTapped(RecurringTransaction)
        case toggleActiveTapped(RecurringTransaction)
        case deleteTapped(RecurringTransaction.ID)
        case form(PresentationAction<RecurringTransactionFormFeature.Action>)
    }

    @Dependency(\.recurringTransactionClient) var client
    @Dependency(\.notificationClient) var notificationClient

    private enum CancelID { case task }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                state.isLoading = true
                return .run { send in
                    let items = (try? await client.fetchAll()) ?? []
                    await send(.loaded(items))
                }

            case let .loaded(items):
                state.isLoading = false
                state.items = items
                return .none

            case .addButtonTapped:
                state.form = RecurringTransactionFormFeature.State(mode: .add)
                return .none

            case let .itemTapped(item):
                state.form = RecurringTransactionFormFeature.State(mode: .edit(item))
                return .none

            case let .toggleActiveTapped(item):
                var updated = item
                updated.isActive.toggle()
                return .run { [updated] send in
                    try? await client.update(updated)
                    if !updated.isActive {
                        await notificationClient.cancelRecurringReminder(updated.id)
                    }
                    let items = (try? await client.fetchAll()) ?? []
                    await send(.loaded(items))
                }

            case let .deleteTapped(id):
                return .run { send in
                    try? await client.delete(id)
                    await notificationClient.cancelRecurringReminder(id)
                    let items = (try? await client.fetchAll()) ?? []
                    await send(.loaded(items))
                }

            case .form(.presented(.delegate(.saved))):
                return .run { send in
                    let items = (try? await client.fetchAll()) ?? []
                    await send(.loaded(items))
                }

            case .form:
                return .none
            }
        }
        .ifLet(\.$form, action: \.form) {
            RecurringTransactionFormFeature()
        }
    }
}
