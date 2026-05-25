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
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    nameSection
                    amountSection
                    periodSection
                    startDateSection
                    if !store.availableCategories.isEmpty {
                        categorySection
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 100)
            }
            .scrollContentBackground(.hidden)
            .background(Color.Design.background)
            .navigationTitle(store.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(String(localized: "common_cancel")) {
                        store.send(.cancelTapped)
                    }
                    .accessibilityIdentifier("budget_form_cancel_button")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "common_save")) {
                        store.send(.saveTapped)
                    }
                    .fontWeight(.semibold)
                    .disabled(!isSaveEnabled)
                    .accessibilityIdentifier("budget_form_save_button")
                }
            }
            .task { await store.send(.task).finish() }
        }
    }

    // MARK: - Save gating

    private var isSaveEnabled: Bool {
        guard !store.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        guard let amount = Decimal(string: store.amountText), amount > 0 else {
            return false
        }
        return true
    }

    // MARK: - Sections

    private var nameSection: some View {
        FormSection("common_name") {
            VStack(alignment: .leading, spacing: 0) {
                TextField(
                    String(localized: "budget_form_name_placeholder"),
                    text: Binding(
                        get: { store.name },
                        set: { store.send(.nameChanged($0)) }
                    )
                )
                .font(.system(size: 17))
                .foregroundStyle(Color.Design.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                if let error = store.nameError {
                    ErrorText(error)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 10)
                }
            }
        }
    }

    private var amountSection: some View {
        FormSection("budget_form_amount") {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Text(verbatim: "NT$")
                        .font(.system(size: 15, weight: .medium, design: .monospaced))
                        .tracking(0.5)
                        .foregroundStyle(Color.Design.textSecondary)

                    TextField(
                        "0",
                        text: Binding(
                            get: { store.amountText },
                            set: { store.send(.amountChanged($0)) }
                        )
                    )
                    .font(.system(size: 32, weight: .medium, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(Color.Design.textPrimary)
                    .keyboardType(.numberPad)

                    Text("/ \(store.period.localizedSuffix)")
                        .font(Font.Design.size14)
                        .foregroundStyle(Color.Design.textSecondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

                if let error = store.amountError {
                    ErrorText(error)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 10)
                } else if let breakdown = breakdownText {
                    Text(breakdown)
                        .font(.system(size: 12, design: .monospaced))
                        .tracking(-0.1)
                        .foregroundStyle(Color.Design.textSecondary)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 10)
                }
            }
        }
    }

    private var breakdownText: String? {
        guard let amount = Decimal(string: store.amountText), amount > 0 else { return nil }
        return amount.perPeriodBreakdown(store.period)
    }

    private var periodSection: some View {
        FormSection("budget_form_period") {
            Picker(
                String(localized: "budget_form_period"),
                selection: Binding(
                    get: { store.period },
                    set: { store.send(.periodChanged($0)) }
                )
            ) {
                ForEach(BudgetPeriod.allCases, id: \.self) { period in
                    Text(period.localizedName).tag(period)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private var startDateSection: some View {
        FormSection("budget_form_start_date") {
            // The section header already labels this row, so the picker
            // sits alone on the trailing edge to avoid a redundant label.
            HStack {
                Spacer(minLength: 0)
                DatePicker(
                    "",
                    selection: Binding(
                        get: { store.startDate },
                        set: { store.send(.startDateChanged($0)) }
                    ),
                    displayedComponents: .date
                )
                .labelsHidden()
                .datePickerStyle(.compact)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private var categorySection: some View {
        FormSection(
            "budget_form_apply_category",
            footerKey: "budget_form_all_expenses_hint"
        ) {
            BudgetCategoryListPicker(
                categories: store.availableCategories,
                selectedId: store.categoryId,
                onSelect: { newId in
                    store.send(.categoryChanged(newId))
                }
            )
        }
    }
}
