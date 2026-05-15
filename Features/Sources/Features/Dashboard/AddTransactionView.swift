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
            ScrollView {
                VStack(spacing: 24) {
                    typeSection
                    amountSection
                    categorySection
                    detailsSection
                    recurringSection
                }
                .padding()
                .padding(.bottom, 80)
            }
            .navigationTitle(
                isEditMode
                    ? String(localized: "add_transaction_edit_title")
                    : String(localized: "add_transaction_title")
            )
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

    // MARK: - Type Section

    private var typeSection: some View {
        Picker(String(localized: "common_type"), selection: Binding(
            get: { store.type },
            set: { store.send(.typeChanged($0)) }
        )) {
            ForEach([TransactionType.expense, .income, .transfer], id: \.self) { type in
                Text(type.displayName).tag(type)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Amount Section

    private var amountSection: some View {
        GlassContainer(
            cornerRadius: 16,
            padding: EdgeInsets(top: 16, leading: 0, bottom: 16, trailing: 0)
        ) {
            VStack(spacing: 8) {
                TextField(String(localized: "add_transaction_amount"), text: Binding(
                    get: { store.amountText },
                    set: { store.send(.amountTextChanged($0)) }
                ))
                .font(.system(size: 48, weight: .bold).monospacedDigit())
                .multilineTextAlignment(.center)
                .keyboardType(.numberPad)

                if let error = store.amountError {
                    Text(error)
                        .font(Font.Design.caption)
                        .foregroundStyle(Color.Design.expenseRed)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Category Section

    @ViewBuilder
    private var categorySection: some View {
        if store.type != .transfer {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(String(localized: "add_transaction_category"))
                        .font(.headline)

                    Spacer()

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
                            Label(
                                String(localized: "add_transaction_ai_suggest_category"),
                                systemImage: "wand.and.sparkles"
                            )
                            .font(Font.Design.caption)
                        }
                        .disabled(store.note.isEmpty)
                    }
                }

                if store.filteredCategories.isEmpty {
                    Text(String(localized: "add_transaction_no_categories"))
                        .foregroundStyle(Color.Design.textTertiary)
                        .font(Font.Design.caption)
                } else {
                    FlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                        ForEach(store.filteredCategories) { category in
                            Button {
                                store.send(.categorySelected(category.id))
                            } label: {
                                CategoryChip(
                                    title: category.localizedName,
                                    systemImage: category.icon,
                                    color: Color(hex: category.color),
                                    isSelected: store.categoryId == category.id,
                                    isSuggested: store.suggestedCategoryNames.contains(category.name)
                                )
                            }
                            .buttonStyle(.plain)
                        }
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
            }
        }
    }

    // MARK: - Details Section (Account + Note + Date)

    private var detailsSection: some View {
        GlassContainer(cornerRadius: 16, padding: 0) {
        VStack(spacing: 0) {
            // Account picker(s)
            if store.type == .transfer {
                Picker(String(localized: "add_transaction_from"), selection: Binding(
                    get: { store.accountId },
                    set: { store.send(.accountSelected($0)) }
                )) {
                    Text(String(localized: "common_please_select")).tag(Optional<Account.ID>.none)
                    ForEach(store.accounts) { account in
                        Text(account.name).tag(Optional(account.id))
                    }
                }
                .pickerStyle(.menu)
                .padding(.vertical, 12)
                .padding(.horizontal, 16)

                Divider().padding(.horizontal, 16)

                Picker(String(localized: "add_transaction_to"), selection: Binding(
                    get: { store.toAccountId },
                    set: { store.send(.toAccountSelected($0)) }
                )) {
                    Text(String(localized: "common_please_select")).tag(Optional<Account.ID>.none)
                    ForEach(store.accounts.filter { $0.id != store.accountId }) { account in
                        Text(account.name).tag(Optional(account.id))
                    }
                }
                .pickerStyle(.menu)
                .padding(.vertical, 12)
                .padding(.horizontal, 16)

                if let error = store.transferError {
                    Text(error)
                        .font(Font.Design.caption)
                        .foregroundStyle(Color.Design.expenseRed)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                }
            } else {
                Picker(String(localized: "add_transaction_account"), selection: Binding(
                    get: { store.accountId },
                    set: { store.send(.accountSelected($0)) }
                )) {
                    Text(String(localized: "common_please_select")).tag(Optional<Account.ID>.none)
                    ForEach(store.accounts) { account in
                        Text(account.name).tag(Optional(account.id))
                    }
                }
                .pickerStyle(.menu)
                .padding(.vertical, 12)
                .padding(.horizontal, 16)

                if let error = store.accountError {
                    Text(error)
                        .font(Font.Design.caption)
                        .foregroundStyle(Color.Design.expenseRed)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                }
            }

            Divider().padding(.horizontal, 16)

            // Note field with voice input
            VStack(alignment: .leading, spacing: 4) {
                if store.isRecording {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.Design.expenseRed)
                            .frame(width: 7, height: 7)
                        Text(String(localized: "speech_recording_label"))
                            .font(Font.Design.caption)
                            .foregroundStyle(Color.Design.expenseRed)
                    }
                }
                HStack {
                    TextField(String(localized: "add_transaction_note_placeholder"), text: Binding(
                        get: { store.note },
                        set: { store.send(.noteChanged($0)) }
                    ))
                    .padding(.vertical, 12)

                    if store.isBackgroundParsingNote {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Button {
                            store.send(.recordingTapped)
                        } label: {
                            Image(systemName: store.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                                .font(.title3)
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(
                                    store.isRecording
                                        ? Color.Design.expenseRed
                                        : Color.Design.textTertiary
                                )
                        }
                        .frame(minWidth: 44, minHeight: 44)
                        .accessibilityLabel(store.isRecording ? String(localized: "a11y_voice_stop") : String(localized: "a11y_voice_start"))
                    }
                }
                if let error = store.speechError {
                    Text(error)
                        .font(Font.Design.caption)
                        .foregroundStyle(Color.Design.expenseRed)
                        .padding(.bottom, 8)
                }
            }
            .padding(.horizontal, 16)

            Divider().padding(.horizontal, 16)

            // Date picker
            DatePicker(
                String(localized: "add_transaction_date"),
                selection: Binding(
                    get: { store.date },
                    set: { store.send(.dateChanged($0)) }
                ),
                displayedComponents: [.date, .hourAndMinute]
            )
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
        }
        }
    }

    // MARK: - Recurring Section

    @ViewBuilder
    private var recurringSection: some View {
        if case .add = store.mode {
            GlassContainer(cornerRadius: 16, padding: 0) {
                VStack(spacing: 0) {
                    Toggle(
                        String(localized: "recurring_transaction_toggle_label"),
                        isOn: Binding(
                            get: { store.recurringFrequency != nil },
                            set: { store.send(.recurringToggled($0)) }
                        )
                    )
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)

                    if store.recurringFrequency != nil {
                        Divider().padding(.horizontal, 16)

                        Picker(
                            String(localized: "recurring_transaction_frequency_label"),
                            selection: Binding(
                                get: { store.recurringFrequency ?? .monthly },
                                set: { store.send(.recurringFrequencyChanged($0)) }
                            )
                        ) {
                            ForEach(BudgetPeriod.allCases, id: \.self) { period in
                                Text(period.localizedName).tag(period)
                            }
                        }
                        .pickerStyle(.menu)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                    }
                }
            }
        }
    }
}
