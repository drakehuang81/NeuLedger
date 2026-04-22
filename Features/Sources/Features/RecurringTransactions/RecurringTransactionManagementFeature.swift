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
        // P1-5: Delete confirmation alert
        @Presents public var alert: AlertState<Action.Alert>?

        public init(items: [RecurringTransaction] = []) { self.items = items }
    }

    public enum Action: Sendable, Equatable {
        case task
        case loaded([RecurringTransaction])
        case addButtonTapped
        case itemTapped(RecurringTransaction)
        case toggleActiveTapped(RecurringTransaction)
        // P1-5: deleteRequested presents confirmation alert
        case deleteRequested(RecurringTransaction.ID)
        // deleteTapped is kept for backward-compatibility with NotificationSettingsView
        // which is outside the allowed modification list; it delegates to deleteRequested
        case deleteTapped(RecurringTransaction.ID)
        case form(PresentationAction<RecurringTransactionFormFeature.Action>)
        // P1-5: Alert presentation action
        case alert(PresentationAction<Alert>)

        @CasePathable
        public enum Alert: Sendable, Equatable {
            case deleteConfirmed(RecurringTransaction.ID)
        }
    }

    @Dependency(\.recurringTransactionClient) var client
    @Dependency(\.notificationClient) var notificationClient
    @Dependency(\.date.now) var now

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
                .cancellable(id: CancelID.task, cancelInFlight: true)

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
                let currentNow = now
                return .run { [updated, currentNow] send in
                    try? await client.update(updated)
                    if !updated.isActive {
                        await notificationClient.cancelRecurringReminder(updated.id)
                    } else {
                        // P0-4: If nextDueDate is in the past, rebase to next valid future date
                        let scheduledDate: Date
                        if updated.nextDueDate < currentNow {
                            scheduledDate = updated.nextDate(after: currentNow)
                        } else {
                            scheduledDate = updated.nextDueDate
                        }
                        try await notificationClient.scheduleRecurringReminder(
                            updated.id,
                            scheduledDate,
                            String(localized: "recurring_transaction_notification_title"),
                            String(localized: "recurring_transaction_notification_body")
                        )
                    }
                    let items = (try? await client.fetchAll()) ?? []
                    await send(.loaded(items))
                }

            // deleteTapped delegates to deleteRequested (backward-compat for NotificationSettingsView)
            case let .deleteTapped(id):
                return .send(.deleteRequested(id))

            // P1-5: Show confirmation alert before deleting
            case let .deleteRequested(id):
                state.alert = AlertState {
                    TextState(String(localized: "alert_delete_recurring_transaction"))
                } actions: {
                    ButtonState(role: .destructive, action: .deleteConfirmed(id)) {
                        TextState(String(localized: "common_delete"))
                    }
                    ButtonState(role: .cancel) {
                        TextState(String(localized: "common_cancel"))
                    }
                } message: {
                    TextState(String(localized: "alert_delete_recurring_transaction_message"))
                }
                return .none

            // P1-5: Actual delete happens only after confirmation
            case let .alert(.presented(.deleteConfirmed(id))):
                return .run { send in
                    try? await client.delete(id)
                    await notificationClient.cancelRecurringReminder(id)
                    let items = (try? await client.fetchAll()) ?? []
                    await send(.loaded(items))
                }

            case .alert:
                return .none

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
        .ifLet(\.$alert, action: \.alert)
    }
}
