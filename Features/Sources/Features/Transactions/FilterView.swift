import Common
import ComposableArchitecture
import Domain
import SwiftUI

public struct FilterView: View {
    @Bindable var store: StoreOf<FilterFeature>

    public init(store: StoreOf<FilterFeature>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            Form {
                // MARK: 類型
                Section("類型") {
                    ForEach([TransactionType.expense, .income, .transfer], id: \.self) { type in
                        Button {
                            store.send(.typeToggled(type))
                        } label: {
                            HStack {
                                Text(type.displayName)
                                    .foregroundStyle(Color.Design.textPrimary)
                                Spacer()
                                if store.selectedTypes.contains(type) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.Design.brandPrimary)
                                }
                            }
                        }
                    }
                }

                // MARK: 分類
                if !store.categories.isEmpty {
                    Section("分類") {
                        ForEach(store.categories) { category in
                            Button {
                                store.send(.categoryToggled(category.id))
                            } label: {
                                HStack {
                                    Label(category.name, systemImage: category.icon)
                                        .foregroundStyle(Color.Design.textPrimary)
                                    Spacer()
                                    if store.selectedCategoryIds.contains(category.id) {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(Color.Design.brandPrimary)
                                    }
                                }
                            }
                        }
                    }
                }

                // MARK: 帳戶
                if !store.accounts.isEmpty {
                    Section("帳戶") {
                        ForEach(store.accounts) { account in
                            Button {
                                store.send(.accountToggled(account.id))
                            } label: {
                                HStack {
                                    Label(account.name, systemImage: account.icon)
                                        .foregroundStyle(Color.Design.textPrimary)
                                    Spacer()
                                    if store.selectedAccountIds.contains(account.id) {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(Color.Design.brandPrimary)
                                    }
                                }
                            }
                        }
                    }
                }

                // MARK: 標籤
                if !store.tags.isEmpty {
                    Section("標籤") {
                        ForEach(store.tags) { tag in
                            Button {
                                store.send(.tagToggled(tag.id))
                            } label: {
                                HStack {
                                    Text(tag.name)
                                        .foregroundStyle(Color.Design.textPrimary)
                                    Spacer()
                                    if store.selectedTagIds.contains(tag.id) {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(Color.Design.brandPrimary)
                                    }
                                }
                            }
                        }
                    }
                }

                // MARK: 日期區間
                Section("日期區間") {
                    DatePicker(
                        "開始日期",
                        selection: Binding(
                            get: { store.startDate ?? Date() },
                            set: { store.send(.startDateChanged($0)) }
                        ),
                        displayedComponents: .date
                    )
                    DatePicker(
                        "結束日期",
                        selection: Binding(
                            get: { store.endDate ?? Date() },
                            set: { store.send(.endDateChanged($0)) }
                        ),
                        displayedComponents: .date
                    )
                    if store.startDate != nil || store.endDate != nil {
                        Button("清除日期") {
                            store.send(.startDateChanged(nil))
                            store.send(.endDateChanged(nil))
                        }
                        .foregroundStyle(Color.Design.expenseRed)
                    }
                }
            }
            .navigationTitle("篩選")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("清除全部") {
                        store.send(.clearAllTapped)
                    }
                    .foregroundStyle(Color.Design.expenseRed)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("套用") {
                        store.send(.applyTapped)
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

private extension TransactionType {
    var displayName: String {
        switch self {
        case .expense: return "支出"
        case .income: return "收入"
        case .transfer: return "轉帳"
        }
    }
}
