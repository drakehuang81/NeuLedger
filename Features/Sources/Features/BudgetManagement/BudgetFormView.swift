import Common
import ComposableArchitecture
import Domain
import SwiftUI

public struct BudgetFormView: View {
    @Bindable var store: StoreOf<BudgetFormFeature>

    public init(store: StoreOf<BudgetFormFeature>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            Form {
                // MARK: Name Field
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("預算名稱", text: Binding(
                            get: { store.name },
                            set: { store.send(.nameChanged($0)) }
                        ))
                        if let error = store.nameError {
                            Text(error)
                                .font(Font.Design.caption)
                                .foregroundStyle(Color.Design.expenseRed)
                        }
                    }
                } header: {
                    Text("名稱")
                }

                // MARK: Amount Field
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("NT$")
                                .foregroundStyle(Color.Design.textSecondary)
                            TextField("0", text: Binding(
                                get: { store.amountText },
                                set: { store.send(.amountChanged($0)) }
                            ))
                            .keyboardType(.numberPad)
                        }
                        if let error = store.amountError {
                            Text(error)
                                .font(Font.Design.caption)
                                .foregroundStyle(Color.Design.expenseRed)
                        }
                    }
                } header: {
                    Text("金額")
                }

                // MARK: Period Picker
                Section {
                    Picker("週期", selection: Binding(
                        get: { store.period },
                        set: { store.send(.periodChanged($0)) }
                    )) {
                        ForEach(BudgetPeriod.allCases, id: \.self) { period in
                            Text(periodDisplayName(period)).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("週期")
                }

                // MARK: Start Date
                Section {
                    DatePicker(
                        "起始日期",
                        selection: Binding(
                            get: { store.startDate },
                            set: { store.send(.startDateChanged($0)) }
                        ),
                        displayedComponents: .date
                    )
                } header: {
                    Text("起始日期")
                }

                // MARK: Category (optional)
                if !store.availableCategories.isEmpty {
                    Section {
                        Picker("分類", selection: Binding(
                            get: { store.categoryId },
                            set: { store.send(.categoryChanged($0)) }
                        )) {
                            Text("全部支出（全域預算）").tag(Domain.Category.ID?.none)
                            ForEach(store.availableCategories) { category in
                                Text(category.name).tag(Optional(category.id))
                            }
                        }
                    } header: {
                        Text("套用分類")
                    } footer: {
                        Text("選擇「全部支出」表示此預算適用所有支出類別。")
                            .font(Font.Design.caption)
                    }
                }
            }
            .navigationTitle(store.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        store.send(.cancelTapped)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
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

    private func periodDisplayName(_ period: BudgetPeriod) -> String {
        switch period {
        case .weekly: return "每週"
        case .monthly: return "每月"
        case .yearly: return "每年"
        }
    }
}
