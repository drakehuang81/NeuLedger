import Common
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
            // Amount & Note
            Section {
                TextField(
                    String(localized: "add_transaction_amount_placeholder"),
                    text: $store.amountText.sending(\.amountChanged)
                )
                .keyboardType(.numberPad)
                if let err = store.amountError {
                    Text(err).font(.caption).foregroundStyle(Color.Design.expenseRed)
                }

                TextField(
                    String(localized: "add_transaction_note_placeholder"),
                    text: $store.note.sending(\.noteChanged)
                )
            }

            // Frequency & Schedule
            Section {
                Picker(
                    String(localized: "recurring_transaction_frequency_label"),
                    selection: $store.frequency.sending(\.frequencyChanged)
                ) {
                    ForEach(BudgetPeriod.allCases, id: \.self) { p in
                        Text(p.localizedName).tag(p)
                    }
                }

                // P0-2: DatePicker for first run date (y/m/d)
                DatePicker(
                    String(localized: "recurring_transaction_first_run_date"),
                    selection: $store.firstRunDate.sending(\.firstRunDateChanged),
                    displayedComponents: .date
                )

                // Time-of-day picker (h/m)
                DatePicker(
                    String(localized: "recurring_transaction_notification_time"),
                    selection: $store.notificationTime.sending(\.notificationTimeChanged),
                    displayedComponents: .hourAndMinute
                )
            }

            // Account
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
                    Text(err).font(.caption).foregroundStyle(Color.Design.expenseRed)
                }
            }

            // P0-3: Inline save error
            if let saveErr = store.saveError {
                Section {
                    Text(saveErr)
                        .font(.caption)
                        .foregroundStyle(Color.Design.expenseRed)
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
