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
                    Picker("類型", selection: Binding(
                        get: { store.type },
                        set: { store.send(.typeChanged($0)) }
                    )) {
                        Text("支出").tag(TransactionType.expense)
                        Text("收入").tag(TransactionType.income)
                        Text("轉帳").tag(TransactionType.transfer)
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
                    Text("金額")
                }

                // MARK: 帳戶
                Section {
                    if store.type == .transfer {
                        // 來源帳戶
                        Picker("從", selection: Binding(
                            get: { store.accountId },
                            set: { store.send(.accountSelected($0)) }
                        )) {
                            Text("請選擇").tag(Optional<Account.ID>.none)
                            ForEach(store.accounts) { account in
                                Text(account.name).tag(Optional(account.id))
                            }
                        }
                        // 目標帳戶
                        Picker("至", selection: Binding(
                            get: { store.toAccountId },
                            set: { store.send(.toAccountSelected($0)) }
                        )) {
                            Text("請選擇").tag(Optional<Account.ID>.none)
                            ForEach(store.accounts.filter { $0.id != store.accountId }) { account in
                                Text(account.name).tag(Optional(account.id))
                            }
                        }
                    } else {
                        Picker("帳戶", selection: Binding(
                            get: { store.accountId },
                            set: { store.send(.accountSelected($0)) }
                        )) {
                            Text("請選擇").tag(Optional<Account.ID>.none)
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
                    Text(store.type == .transfer ? "帳戶" : "帳戶")
                }

                // MARK: 分類（非轉帳）
                if store.type != .transfer {
                    Section {
                        if store.filteredCategories.isEmpty {
                            Text("無可用分類")
                                .foregroundStyle(Color.Design.textTertiary)
                        } else {
                            Picker("分類", selection: Binding(
                                get: { store.categoryId },
                                set: { store.send(.categorySelected($0)) }
                            )) {
                                Text("請選擇").tag(Optional<Domain.Category.ID>.none)
                                ForEach(store.filteredCategories) { category in
                                Label(category.name, systemImage: category.icon)
                                    .tag(Optional<Domain.Category.ID>(category.id))
                            }
                            }
                        }
                        if let error = store.categoryError {
                            Text(error)
                                .font(Font.Design.caption)
                                .foregroundStyle(Color.Design.expenseRed)
                        }
                    } header: {
                        Text("分類")
                    }
                }

                // MARK: 備註
                Section {
                    TextField("選填", text: Binding(
                        get: { store.note },
                        set: { store.send(.noteChanged($0)) }
                    ))
                } header: {
                    Text("備註")
                }

                // MARK: 日期
                Section {
                    DatePicker(
                        "日期",
                        selection: Binding(
                            get: { store.date },
                            set: { store.send(.dateChanged($0)) }
                        ),
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }
            }
            .navigationTitle(isEditMode ? "編輯交易" : "新增交易")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        store.send(.dismiss)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存") {
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
