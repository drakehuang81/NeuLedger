import Common
import ComposableArchitecture
import Domain
import SwiftUI

public struct AddTransactionView: View {
    @Bindable var store: StoreOf<AddTransactionFeature>

    public init(store: StoreOf<AddTransactionFeature>) {
        self.store = store
    }

    private var isEditMode: Bool {
        if case .edit = store.mode { return true }
        return false
    }

    public var body: some View {
        NavigationStack {
            Form {
                // MARK: 交易類型
                Section {
                    Picker(String(localized: "common_type"), selection: Binding(
                        get: { store.type },
                        set: { store.send(.typeChanged($0)) }
                    )) {
                        Text("common_expense").tag(TransactionType.expense)
                        Text("common_income").tag(TransactionType.income)
                        Text("common_transfer").tag(TransactionType.transfer)
                    }
                    .pickerStyle(.segmented)
                    .listRowInsets(.init(top: 12, leading: 16, bottom: 12, trailing: 16))
                }

                // MARK: 金額
                Section {
                    HStack {
                        Text("NT$")
                            .foregroundStyle(Color.Design.textSecondary)
                            .font(Font.Design.amount)
                        TextField("0", text: Binding(
                            get: { store.amountText },
                            set: { store.send(.amountTextChanged($0)) }
                        ))
                        .keyboardType(.numberPad)
                        .font(Font.Design.amount.weight(.semibold))
                        .multilineTextAlignment(.trailing)
                    }
                    if let error = store.amountError {
                        Text(error)
                            .font(Font.Design.caption)
                            .foregroundStyle(Color.Design.expenseRed)
                    }
                } header: {
                    Text("add_transaction_amount")
                }

                // MARK: 帳戶
                Section {
                    if store.type == .transfer {
                        // 來源帳戶
                        Picker(String(localized: "add_transaction_from"), selection: Binding(
                            get: { store.accountId },
                            set: { store.send(.accountSelected($0)) }
                        )) {
                            Text("common_please_select").tag(Optional<Account.ID>.none)
                            ForEach(store.accounts) { account in
                                Text(account.name).tag(Optional(account.id))
                            }
                        }
                        // 目標帳戶
                        Picker(String(localized: "add_transaction_to"), selection: Binding(
                            get: { store.toAccountId },
                            set: { store.send(.toAccountSelected($0)) }
                        )) {
                            Text("common_please_select").tag(Optional<Account.ID>.none)
                            ForEach(store.accounts.filter { $0.id != store.accountId }) { account in
                                Text(account.name).tag(Optional(account.id))
                            }
                        }
                        if let error = store.transferError {
                            Text(error)
                                .font(Font.Design.caption)
                                .foregroundStyle(Color.Design.expenseRed)
                        }
                    } else {
                        Picker(String(localized: "add_transaction_account"), selection: Binding(
                            get: { store.accountId },
                            set: { store.send(.accountSelected($0)) }
                        )) {
                            Text("common_please_select").tag(Optional<Account.ID>.none)
                            ForEach(store.accounts) { account in
                                Text(account.name).tag(Optional(account.id))
                            }
                        }
                    }
                    if let error = store.accountError {
                        Text(error)
                            .font(Font.Design.caption)
                            .foregroundStyle(Color.Design.expenseRed)
                    }
                } header: {
                    Text("add_transaction_account")
                }

                // MARK: 分類（非轉帳）
                if store.type != .transfer {
                    Section {
                        if store.filteredCategories.isEmpty {
                            Text("add_transaction_no_categories")
                                .foregroundStyle(Color.Design.textTertiary)
                        } else {
                            Picker(String(localized: "add_transaction_category"), selection: Binding(
                                get: { store.categoryId },
                                set: { store.send(.categorySelected($0)) }
                            )) {
                                Text("common_please_select").tag(Optional<Domain.Category.ID>.none)
                                ForEach(store.filteredCategories) { category in
                                    HStack {
                                        Label(category.name, systemImage: category.icon)
                                        Spacer()
                                        // Highlight AI-suggested categories with a sparkle badge
                                        if store.suggestedCategoryNames.contains(category.name) {
                                            Image(systemName: "sparkles")
                                                .foregroundStyle(Color.accentColor)
                                                .font(.caption)
                                        }
                                    }
                                    .tag(Optional<Domain.Category.ID>(category.id))
                                }
                            }
                        }

                        // AI suggest button row
                        HStack {
                            if store.isSuggestingCategory {
                                ProgressView()
                                    .controlSize(.small)
                                Text(String(localized: "add_transaction_ai_suggesting"))
                                    .font(Font.Design.caption)
                                    .foregroundStyle(Color.Design.textSecondary)
                            } else {
                                Button {
                                    store.send(.suggestCategoryTapped)
                                } label: {
                                    Label(String(localized: "add_transaction_ai_suggest_category"), systemImage: "wand.and.sparkles")
                                        .font(Font.Design.caption)
                                }
                                .disabled(store.note.isEmpty)
                            }
                        }

                        if let error = store.categoryError {
                            Text(error)
                                .font(Font.Design.caption)
                                .foregroundStyle(Color.Design.expenseRed)
                        }
                        if let error = store.categorySuggestionError {
                            Text(error)
                                .font(Font.Design.caption)
                                .foregroundStyle(Color.Design.expenseRed)
                        }
                    } header: {
                        Text("add_transaction_category")
                    }
                }

                // MARK: 備註
                Section {
                    HStack {
                        TextField(String(localized: "add_transaction_note_placeholder"), text: Binding(
                            get: { store.note },
                            set: { store.send(.noteChanged($0)) }
                        ))
                        if store.isBackgroundParsingNote {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                } header: {
                    Text("add_transaction_note")
                }

                // MARK: 日期
                Section {
                    DatePicker(
                        String(localized: "add_transaction_date"),
                        selection: Binding(
                            get: { store.date },
                            set: { store.send(.dateChanged($0)) }
                        ),
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }
            }
            .navigationTitle(isEditMode ? String(localized: "add_transaction_edit_title") : String(localized: "add_transaction_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common_cancel")) {
                        store.send(.dismiss)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common_save")) {
                        store.send(.saveTapped)
                    }
                    .fontWeight(.semibold)
                }
            }
            .task {
                await store.send(.task).finish()
            }
        }
    }
}
