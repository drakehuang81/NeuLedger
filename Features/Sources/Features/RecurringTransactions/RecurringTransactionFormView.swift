import SwiftUI
import ComposableArchitecture
import Domain

public struct RecurringTransactionFormView: View {
    @Bindable var store: StoreOf<RecurringTransactionFormFeature>

    public init(store: StoreOf<RecurringTransactionFormFeature>) {
        self.store = store
    }

    public var body: some View {
        Form {
            Section {
                TextField(
                    String(localized: "add_transaction_amount_placeholder"),
                    text: $store.amountText.sending(\.amountChanged)
                )
                .keyboardType(.numberPad)
                if let err = store.amountError {
                    Text(err).font(.caption).foregroundStyle(.red)
                }

                TextField(
                    String(localized: "add_transaction_note_placeholder"),
                    text: $store.note.sending(\.noteChanged)
                )
            }

            Section {
                Picker(
                    String(localized: "recurring_transaction_frequency_label"),
                    selection: $store.frequency.sending(\.frequencyChanged)
                ) {
                    ForEach(BudgetPeriod.allCases, id: \.self) { p in
                        Text(p.localizedName).tag(p)
                    }
                }
                DatePicker(
                    String(localized: "recurring_transaction_notification_time"),
                    selection: $store.notificationTime.sending(\.notificationTimeChanged),
                    displayedComponents: .hourAndMinute
                )
            }

            Section {
                Picker(
                    String(localized: "add_transaction_account_label"),
                    selection: $store.accountId.sending(\.accountChanged)
                ) {
                    Text(String(localized: "add_transaction_select_account")).tag(Optional<Account.ID>(nil))
                    ForEach(store.accounts) { acc in
                        Text(acc.name).tag(Optional(acc.id))
                    }
                }
                if let err = store.accountError {
                    Text(err).font(.caption).foregroundStyle(.red)
                }
            }
        }
        .navigationTitle(
            store.mode == .add
                ? String(localized: "recurring_transaction_add_title")
                : String(localized: "recurring_transaction_edit_title")
        )
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "common_cancel")) { store.send(.cancelTapped) }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(String(localized: "common_save")) { store.send(.saveTapped) }
            }
        }
        .task { await store.send(.task).finish() }
    }
}
