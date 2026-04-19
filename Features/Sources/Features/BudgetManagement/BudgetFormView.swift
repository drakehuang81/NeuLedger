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
                        TextField(String(localized: "budget_form_name_placeholder"), text: Binding(
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
                    Text("common_name")
                }

                // MARK: Amount Field
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(verbatim: "NT$")
                                .font(Font.Design.amount)
                                .foregroundStyle(Color.Design.textSecondary)
                            TextField("0", text: Binding(
                                get: { store.amountText },
                                set: { store.send(.amountChanged($0)) }
                            ))
                            .font(Font.Design.amount)
                            .monospacedDigit()
                            .keyboardType(.numberPad)
                        }
                        if let error = store.amountError {
                            Text(error)
                                .font(Font.Design.caption)
                                .foregroundStyle(Color.Design.expenseRed)
                        }
                    }
                } header: {
                    Text("budget_form_amount")
                }

                // MARK: Period Picker
                Section {
                    Picker(String(localized: "budget_form_period"), selection: Binding(
                        get: { store.period },
                        set: { store.send(.periodChanged($0)) }
                    )) {
                        ForEach(BudgetPeriod.allCases, id: \.self) { period in
                            Text(periodDisplayName(period)).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("budget_form_period")
                }

                // MARK: Start Date
                Section {
                    DatePicker(
                        String(localized: "budget_form_start_date"),
                        selection: Binding(
                            get: { store.startDate },
                            set: { store.send(.startDateChanged($0)) }
                        ),
                        displayedComponents: .date
                    )
                } header: {
                    Text("budget_form_start_date")
                }

                // MARK: Category (optional)
                if !store.availableCategories.isEmpty {
                    Section {
                        Picker(String(localized: "add_transaction_category"), selection: Binding(
                            get: { store.categoryId },
                            set: { store.send(.categoryChanged($0)) }
                        )) {
                            Text("budget_form_all_expenses").tag(Domain.Category.ID?.none)
                            ForEach(store.availableCategories) { category in
                                Text(category.name).tag(Optional(category.id))
                            }
                        }
                    } header: {
                        Text("budget_form_apply_category")
                    } footer: {
                        Text("budget_form_all_expenses_hint")
                            .font(Font.Design.caption)
                    }
                }
            }
            .navigationTitle(store.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(String(localized: "common_cancel")) {
                        store.send(.cancelTapped)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
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

    private func periodDisplayName(_ period: BudgetPeriod) -> String {
        switch period {
        case .weekly: return String(localized: "budget_period_weekly")
        case .monthly: return String(localized: "budget_period_monthly")
        case .yearly: return String(localized: "budget_period_yearly")
        }
    }
}
