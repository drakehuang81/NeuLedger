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
        NavigationStack {
            ZStack {
                WarmGradientBackground(variant: .top)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 22) {
                        typeSection
                        amountSection
                        detailsSection
                        frequencySection
                        scheduleSection
                        if let saveErr = store.saveError {
                            saveErrorSection(saveErr)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 60)
                }
            }
            .navigationTitle(
                store.mode == .add
                    ? String(localized: "recurring_transaction_add_title")
                    : String(localized: "recurring_transaction_edit_title")
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common_cancel")) {
                        store.send(.cancelTapped)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common_save")) {
                        store.send(.saveTapped)
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .task { await store.send(.task).finish() }
    }

    // MARK: - Type Section

    private var typeSection: some View {
        sectionGroup(label: "common_type") {
            HStack(spacing: 0) {
                typePill(.expense,
                         label: "common_expense",
                         activeColor: Color.Design.expenseRed)
                typePill(.income,
                         label: "common_income",
                         activeColor: Color.Design.incomeGreen)
                typePill(.transfer,
                         label: "common_transfer",
                         activeColor: Color.Design.transferPurple)
            }
            .padding(3)
            .background {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.Design.textPrimary.opacity(0.06))
            }
        }
    }

    private func typePill(
        _ type: TransactionType,
        label: LocalizedStringKey,
        activeColor: Color
    ) -> some View {
        let isActive = store.type == type
        return Button {
            store.send(.typeChanged(type))
        } label: {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(
                    isActive ? activeColor : Color.Design.textSecondary
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background {
                    if isActive {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Color.Design.surface)
                            .shadow(color: .black.opacity(0.08), radius: 3, y: 1)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Amount Section

    private var amountSection: some View {
        sectionGroup(label: "recurring_form_amount_section") {
            VStack(alignment: .leading, spacing: 6) {
                GlassContainer(cornerRadius: 16, padding: 0) {
                    HStack(spacing: 6) {
                        Text("NT$")
                            .font(.system(.body, design: .monospaced).weight(.medium))
                            .foregroundStyle(Color.Design.textSecondary)
                            .padding(.leading, 16)
                        TextField(
                            "0",
                            text: $store.amountText.sending(\.amountChanged)
                        )
                        .font(.system(size: 34, weight: .semibold, design: .monospaced).monospacedDigit())
                        .foregroundStyle(Color.Design.textPrimary)
                        .keyboardType(.numberPad)
                        .padding(.vertical, 14)
                        .padding(.trailing, 16)
                    }
                }
                if let err = store.amountError {
                    ErrorText(err)
                        .padding(.horizontal, 4)
                }
            }
        }
    }

    // MARK: - Details Section (Note / Category / Account)

    private var detailsSection: some View {
        sectionGroup(label: "recurring_form_details_section") {
            GlassContainer(cornerRadius: 16, padding: 0) {
                VStack(spacing: 0) {
                    // Note
                    formRow(label: String(localized: "add_transaction_note_placeholder")) {
                        TextField(
                            String(localized: "add_transaction_note_placeholder"),
                            text: $store.note.sending(\.noteChanged)
                        )
                        .font(Font.Design.body)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(Color.Design.textPrimary)
                    }
                    rowDivider

                    // Category picker
                    Menu {
                        Button(String(localized: "add_transaction_select_category")) {
                            store.send(.categoryChanged(nil))
                        }
                        ForEach(store.categories.filter {
                            $0.type == store.type || store.type == .transfer
                        }) { cat in
                            Button {
                                store.send(.categoryChanged(cat.id))
                            } label: {
                                Label(cat.name, systemImage: cat.icon)
                            }
                        }
                    } label: {
                        formRow(label: String(localized: "add_transaction_category_label")) {
                            if let catId = store.categoryId,
                               let cat = store.categories.first(where: { $0.id == catId }) {
                                HStack(spacing: 6) {
                                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                                        .fill(Color.Design.fromHex(cat.color))
                                        .frame(width: 20, height: 20)
                                        .overlay {
                                            Image(systemName: cat.icon)
                                                .font(.system(size: 11, weight: .semibold))
                                                .foregroundStyle(.white)
                                        }
                                    Text(cat.name)
                                        .font(Font.Design.body)
                                        .foregroundStyle(Color.Design.textPrimary)
                                }
                            } else {
                                Text(String(localized: "add_transaction_select_category"))
                                    .font(Font.Design.body)
                                    .foregroundStyle(Color.Design.textTertiary)
                            }
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color.Design.textTertiary)
                        }
                    }

                    rowDivider

                    // Account picker
                    VStack(alignment: .leading, spacing: 4) {
                        Menu {
                            Button(String(localized: "add_transaction_select_account")) {
                                store.send(.accountChanged(nil))
                            }
                            ForEach(store.accounts) { acc in
                                Button {
                                    store.send(.accountChanged(acc.id))
                                } label: {
                                    Label(acc.name, systemImage: acc.icon)
                                }
                            }
                        } label: {
                            formRow(label: String(localized: "add_transaction_account_label")) {
                                if let accId = store.accountId,
                                   let acc = store.accounts.first(where: { $0.id == accId }) {
                                    HStack(spacing: 6) {
                                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                                            .fill(Color.Design.fromHex(acc.color))
                                            .frame(width: 20, height: 20)
                                            .overlay {
                                                Image(systemName: acc.icon)
                                                    .font(.system(size: 11, weight: .semibold))
                                                    .foregroundStyle(.white)
                                            }
                                        Text(acc.name)
                                            .font(Font.Design.body)
                                            .foregroundStyle(Color.Design.textPrimary)
                                    }
                                } else {
                                    Text(String(localized: "add_transaction_select_account"))
                                        .font(Font.Design.body)
                                        .foregroundStyle(Color.Design.textTertiary)
                                }
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(Color.Design.textTertiary)
                            }
                        }
                        if let err = store.accountError {
                            ErrorText(err)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 8)
                        }
                    }

                    // TODO: toAccount row (transfer destination) — requires
                    // RecurringTransactionFormFeature.State to expose toAccount picker
                    // in a way that drives a separate UI row; for now the toAccountId
                    // is set silently when type == .transfer. Revisit when design
                    // specifies a second account picker for transfers.
                }
            }
        }
    }

    // MARK: - Frequency Section

    private var frequencySection: some View {
        sectionGroup(label: "recurring_transaction_frequency_label") {
            HStack(spacing: 0) {
                frequencyPill(.weekly,  label: "recurring_form_freq_weekly")
                frequencyPill(.monthly, label: "recurring_form_freq_monthly")
                frequencyPill(.yearly,  label: "recurring_form_freq_yearly")
            }
            .padding(3)
            .background {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.Design.textPrimary.opacity(0.06))
            }
        }
    }

    private func frequencyPill(
        _ period: BudgetPeriod,
        label: LocalizedStringKey
    ) -> some View {
        let isActive = store.frequency == period
        return Button {
            store.send(.frequencyChanged(period))
        } label: {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(
                    isActive ? Color.Design.textPrimary : Color.Design.textSecondary
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background {
                    if isActive {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Color.Design.surface)
                            .shadow(color: .black.opacity(0.08), radius: 3, y: 1)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Schedule Section (first run date + notification time)

    private var scheduleSection: some View {
        sectionGroup(label: "recurring_form_schedule_section") {
            GlassContainer(cornerRadius: 16, padding: 0) {
                VStack(spacing: 0) {
                    // First run / next due date
                    HStack {
                        Text(String(localized: "recurring_transaction_first_run_date"))
                            .font(Font.Design.body)
                            .foregroundStyle(Color.Design.textPrimary)
                        Spacer()
                        DatePicker(
                            "",
                            selection: $store.firstRunDate.sending(\.firstRunDateChanged),
                            displayedComponents: .date
                        )
                        .labelsHidden()
                        .tint(Color.accentColor)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                    rowDivider

                    // Notification time
                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: "bell.fill")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.accentColor)
                            Text(String(localized: "recurring_transaction_notification_time"))
                                .font(Font.Design.body)
                                .foregroundStyle(Color.Design.textPrimary)
                        }
                        Spacer()
                        DatePicker(
                            "",
                            selection: $store.notificationTime.sending(\.notificationTimeChanged),
                            displayedComponents: .hourAndMinute
                        )
                        .labelsHidden()
                        .tint(Color.accentColor)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
            }

            nextDueDateFooter
        }
    }

    private var nextDueDateFooter: some View {
        HStack(spacing: 4) {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.Design.textTertiary)
            Text(nextDueDateLabel)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(Color.Design.textTertiary)
        }
        .padding(.horizontal, 6)
    }

    private var nextDueDateLabel: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        let timeComponents = Calendar.current.dateComponents([.hour, .minute], from: store.notificationTime)
        let combined = Calendar.current.date(
            bySettingHour: timeComponents.hour ?? 9,
            minute: timeComponents.minute ?? 0,
            second: 0,
            of: store.firstRunDate
        ) ?? store.firstRunDate
        let dateStr = formatter.string(from: combined)
        return String(
            format: String(localized: "recurring_form_next_due_footer"),
            dateStr
        )
    }

    // MARK: - Save Error Section

    private func saveErrorSection(_ message: String) -> some View {
        GlassContainer(cornerRadius: 12, padding: 12) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.Design.expenseRed)
                Text(message)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.Design.expenseRed)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Helpers

    private var rowDivider: some View {
        Color.Design.separator.opacity(0.4)
            .frame(height: 0.5)
            .padding(.leading, 16)
    }

    @ViewBuilder
    private func formRow<Content: View>(
        label: String,
        @ViewBuilder trailing: () -> Content
    ) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(Font.Design.body)
                .foregroundStyle(Color.Design.textPrimary)
                .fixedSize()
            Spacer()
            HStack(spacing: 6) {
                trailing()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Section Group helper

    @ViewBuilder
    private func sectionGroup<Content: View>(
        label: LocalizedStringKey,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .textCase(.uppercase)
                .tracking(1.2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
            content()
        }
    }
}

#Preview("Add") {
    RecurringTransactionFormView(
        store: Store(initialState: RecurringTransactionFormFeature.State(mode: .add)) {
            RecurringTransactionFormFeature()
        }
    )
}
