import Common
import ComposableArchitecture
import Domain
import SwiftUI

public struct AddTransactionView: View {
    @Bindable var store: StoreOf<AddTransactionFeature>
    @State private var activeSheet: ActiveSheet?
    @FocusState private var focusedField: Field?

    private enum ActiveSheet: Int, Identifiable {
        case category, account, toAccount, date
        var id: Int { rawValue }
    }

    private enum Field: Hashable {
        case amount, note
    }

    public init(store: StoreOf<AddTransactionFeature>) {
        self.store = store
    }

    // MARK: - Derived

    private var isEditMode: Bool {
        if case .edit = store.mode { return true }
        return false
    }

    private var navigationTitleText: String {
        isEditMode
            ? String(localized: "add_transaction_edit_title")
            : String(localized: "add_transaction_title")
    }

    private var amountTint: Color {
        switch store.type {
        case .expense:  Color.Design.expenseRed
        case .income:   Color.Design.incomeGreen
        case .transfer: Color.Design.transferPurple
        }
    }

    private var amountSignPrefix: String {
        guard !store.amountText.isEmpty else { return "" }
        switch store.type {
        case .expense:  return "−"
        case .income:   return "+"
        case .transfer: return ""
        }
    }

    private var selectedCategory: Domain.Category? {
        guard let id = store.categoryId else { return nil }
        return store.filteredCategories.first { $0.id == id } ?? store.categories.first { $0.id == id }
    }

    private var selectedAccount: Account? {
        guard let id = store.accountId else { return nil }
        return store.accounts.first { $0.id == id }
    }

    private var selectedToAccount: Account? {
        guard let id = store.toAccountId else { return nil }
        return store.accounts.first { $0.id == id }
    }

    // MARK: - Body

    public var body: some View {
        NavigationStack {
            ZStack {
                WarmGradientBackground(variant: .top)
                    .contentShape(Rectangle())
                    .onTapGesture { focusedField = nil }

                // Dynamic accent orb — colour follows transaction type
                Circle()
                    .fill(amountTint)
                    .frame(width: 240, height: 240)
                    .blur(radius: 80)
                    .opacity(0.22)
                    .offset(x: 120, y: -160)
                    .allowsHitTesting(false)
                    .animation(.easeOut(duration: 0.25), value: store.type)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 14) {
                        typeSegment
                        amountHero
                        fieldsCard
                        recurringSection
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 4)
                    .padding(.bottom, 120)
                    .background(
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture { focusedField = nil }
                    )
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(navigationTitleText)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common_cancel")) { store.send(.dismiss) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common_save")) { store.send(.saveTapped) }
                        .fontWeight(.semibold)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button {
                        focusedField = nil
                    } label: {
                        Image(systemName: "keyboard.chevron.compact.down")
                    }
                    .accessibilityLabel(String(localized: "a11y_dismiss_keyboard"))
                }
            }
            .task { await store.send(.task).finish() }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .category:  categorySheet
                case .account:   accountSheet(isToAccount: false)
                case .toAccount: accountSheet(isToAccount: true)
                case .date:      dateSheet
                }
            }
        }
    }

    // MARK: - Type segmented

    private var typeSegment: some View {
        HStack(spacing: 2) {
            ForEach([TransactionType.expense, .income, .transfer], id: \.self) { type in
                typeSegmentButton(type)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.Design.textPrimary.opacity(0.05))
        )
    }

    private func typeSegmentButton(_ type: TransactionType) -> some View {
        let isSelected = store.type == type
        let tint: Color = switch type {
        case .expense:  Color.Design.expenseRed
        case .income:   Color.Design.incomeGreen
        case .transfer: Color.Design.transferPurple
        }
        return Button {
            store.send(.typeChanged(type))
        } label: {
            Text(type.displayName)
                .font(isSelected ? Font.Design.size14Semibold : Font.Design.size14Medium)
                .foregroundStyle(isSelected ? tint : Color.Design.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.Design.surface)
                        .opacity(isSelected ? 1 : 0)
                        .shadow(color: .black.opacity(isSelected ? 0.08 : 0), radius: 3, x: 0, y: 1)
                )
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.18), value: isSelected)
    }

    // MARK: - Amount hero

    private var amountHero: some View {
        GlassContainer(cornerRadius: 22, padding: EdgeInsets(top: 18, leading: 22, bottom: 18, trailing: 22)) {
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "add_transaction_amount"))
                    .font(Font.Design.size10Medium)
                    .monospaced()
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.Design.textSecondary)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("NT$")
                        .font(Font.Design.size18.monospacedDigit())
                        .foregroundStyle(store.amountText.isEmpty ? Color.Design.textSecondary : amountTint)

                    if !amountSignPrefix.isEmpty {
                        Text(amountSignPrefix)
                            .font(Font.Design.size44Medium.monospacedDigit())
                            .foregroundStyle(amountTint)
                    }

                    TextField("0", text: $store.amountText)
                    .keyboardType(.numberPad)
                    .focused($focusedField, equals: .amount)
                    .font(Font.Design.size44Medium.monospacedDigit())
                    .foregroundStyle(store.amountText.isEmpty ? Color.Design.textSecondary : amountTint)
                    .tint(amountTint)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let error = store.amountError {
                    Text(error)
                        .font(Font.Design.caption)
                        .foregroundStyle(Color.Design.expenseRed)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Field group card

    private var fieldsCard: some View {
        GlassContainer(cornerRadius: 18, padding: 0) {
            VStack(spacing: 0) {
                if store.type != .transfer {
                    fieldRow(label: String(localized: "add_transaction_category"), showChevron: true) {
                        activeSheet = .category
                    } content: {
                        categoryFieldValue
                    }
                    rowDivider

                    if let error = store.categoryError {
                        inlineError(error)
                    }
                    if let error = store.categorySuggestionError {
                        inlineError(error)
                    }
                }

                fieldRow(
                    label: store.type == .transfer
                        ? String(localized: "add_transaction_from")
                        : String(localized: "add_transaction_account"),
                    showChevron: true
                ) {
                    activeSheet = .account
                } content: {
                    accountFieldValue(account: selectedAccount)
                }

                if let error = store.accountError {
                    inlineError(error)
                }

                if store.type == .transfer {
                    rowDivider
                    fieldRow(label: String(localized: "add_transaction_to"), showChevron: true) {
                        activeSheet = .toAccount
                    } content: {
                        accountFieldValue(account: selectedToAccount)
                    }
                    if let error = store.transferError {
                        inlineError(error)
                    }
                }

                rowDivider

                fieldRow(label: String(localized: "add_transaction_date"), showChevron: true) {
                    activeSheet = .date
                } content: {
                    Text(store.date.formatted(date: .abbreviated, time: .shortened))
                        .font(Font.Design.size14Medium)
                        .foregroundStyle(Color.Design.textPrimary)
                }

                rowDivider

                noteRow

                if let error = store.speechError {
                    inlineError(error)
                }
            }
        }
    }

    // MARK: - FieldRow primitive

    @ViewBuilder
    private func fieldRow<Content: View>(
        label: String,
        showChevron: Bool,
        onTap: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Button {
            onTap?()
        } label: {
            HStack(spacing: 10) {
                Text(label)
                    .font(Font.Design.size13)
                    .foregroundStyle(Color.Design.textSecondary)
                    .frame(width: 56, alignment: .leading)

                HStack(spacing: 8) {
                    content()
                    Spacer(minLength: 0)
                }

                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(Font.Design.size11Semibold)
                        .foregroundStyle(Color.Design.textSecondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(onTap == nil)
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(Color.Design.separator.opacity(0.5))
            .frame(height: 0.5)
            .padding(.leading, 14)
    }

    private func inlineError(_ text: String) -> some View {
        Text(text)
            .font(Font.Design.caption)
            .foregroundStyle(Color.Design.expenseRed)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.bottom, 8)
    }

    // MARK: - Field value views

    @ViewBuilder
    private var categoryFieldValue: some View {
        if let category = selectedCategory {
            let tint = Color.Design.fromHex(category.color)
            HStack(spacing: 8) {
                ZStack {
                    Circle().fill(tint.opacity(0.18))
                    Image(systemName: category.icon)
                        .font(Font.Design.size12Medium)
                        .foregroundStyle(tint)
                }
                .frame(width: 26, height: 26)

                Text(category.localizedName)
                    .font(Font.Design.size14Medium)
                    .foregroundStyle(Color.Design.textPrimary)

                if store.isSuggestingCategory {
                    ProgressView().controlSize(.mini)
                }
            }
        } else {
            HStack(spacing: 8) {
                Text(String(localized: "common_please_select"))
                    .font(Font.Design.size14)
                    .foregroundStyle(Color.Design.textTertiary)
                if store.isSuggestingCategory {
                    ProgressView().controlSize(.mini)
                }
            }
        }
    }

    @ViewBuilder
    private func accountFieldValue(account: Account?) -> some View {
        if let account {
            HStack(spacing: 8) {
                Circle().fill(Color.Design.fromHex(account.color)).frame(width: 8, height: 8)
                Text(account.name)
                    .font(Font.Design.size14Medium)
                    .foregroundStyle(Color.Design.textPrimary)
            }
        } else {
            Text(String(localized: "common_please_select"))
                .font(Font.Design.size14)
                .foregroundStyle(Color.Design.textTertiary)
        }
    }

    // MARK: - Note row (with voice + AI parse indicator)

    private var noteRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            if store.isRecording {
                HStack(spacing: 6) {
                    Circle().fill(Color.Design.expenseRed).frame(width: 7, height: 7)
                    Text(String(localized: "speech_recording_label"))
                        .font(Font.Design.caption)
                        .foregroundStyle(Color.Design.expenseRed)
                }
                .padding(.horizontal, 14)
                .padding(.top, 8)
            }

            HStack(spacing: 10) {
                Text(String(localized: "add_transaction_note_placeholder"))
                    .font(Font.Design.size13)
                    .foregroundStyle(Color.Design.textSecondary)
                    .frame(width: 56, alignment: .leading)

                TextField(
                    "",
                    text: $store.note,
                    prompt: Text(String(localized: "common_optional"))
                        .foregroundStyle(Color.Design.textTertiary)
                )
                .focused($focusedField, equals: .note)
                .font(Font.Design.size14)
                .foregroundStyle(Color.Design.textPrimary)
                .submitLabel(.done)
                .onSubmit { focusedField = nil }

                if store.isBackgroundParsingNote {
                    ProgressView().controlSize(.small)
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
                    .frame(minWidth: 28, minHeight: 28)
                    .accessibilityLabel(
                        store.isRecording
                            ? String(localized: "a11y_voice_stop")
                            : String(localized: "a11y_voice_start")
                    )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
        }
    }

    // MARK: - Recurring section

    @ViewBuilder
    private var recurringSection: some View {
        if case .add = store.mode {
            GlassContainer(cornerRadius: 18, padding: 0) {
                VStack(spacing: 0) {
                    Toggle(
                        String(localized: "recurring_transaction_toggle_label"),
                        isOn: Binding(
                            get: { store.recurringFrequency != nil },
                            set: { store.send(.recurringToggled($0)) }
                        )
                    )
                    .font(Font.Design.size14Medium)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)

                    if store.recurringFrequency != nil {
                        rowDivider

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
                        .font(Font.Design.size14)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                    }
                }
            }
        }
    }

    // MARK: - Category sheet

    private var categorySheet: some View {
        NavigationStack {
            ZStack {
                WarmGradientBackground(variant: .center)

                ScrollView {
                    VStack(spacing: 16) {
                        if store.type != .transfer && !store.note.isEmpty {
                            HStack {
                                Spacer()
                                if store.isSuggestingCategory {
                                    HStack(spacing: 6) {
                                        ProgressView().controlSize(.small)
                                        Text(String(localized: "add_transaction_ai_suggesting"))
                                            .font(Font.Design.caption)
                                            .foregroundStyle(Color.Design.textSecondary)
                                    }
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
                                }
                            }
                            .padding(.horizontal, 18)
                        }

                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 76), spacing: 10)],
                            spacing: 10
                        ) {
                            ForEach(store.filteredCategories) { category in
                                Button {
                                    store.send(.categorySelected(category.id))
                                    activeSheet = nil
                                } label: {
                                    categoryTile(category: category)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 18)
                    }
                    .padding(.vertical, 14)
                }
            }
            .navigationTitle(Text(String(localized: "add_transaction_category")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common_cancel")) { activeSheet = nil }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func categoryTile(category: Domain.Category) -> some View {
        let tint = Color.Design.fromHex(category.color)
        let isSelected = store.categoryId == category.id
        let isSuggested = store.suggestedCategoryNames.contains(category.name)
        return VStack(spacing: 4) {
            ZStack {
                Circle().fill(tint.opacity(isSelected ? 0.22 : 0.14))
                Image(systemName: category.icon)
                    .font(Font.Design.size18Medium)
                    .foregroundStyle(tint)
            }
            .frame(width: 40, height: 40)

            Text(category.localizedName)
                .font(isSelected ? Font.Design.size11Semibold : Font.Design.size11Medium)
                .foregroundStyle(isSelected ? tint : Color.Design.textPrimary)
                .lineLimit(1)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isSelected ? tint.opacity(0.10) : Color.Design.surface.opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isSelected ? tint : Color.clear, lineWidth: 1)
        )
        .overlay(alignment: .topTrailing) {
            if isSuggested {
                Image(systemName: "sparkles")
                    .font(Font.Design.size10Medium)
                    .foregroundStyle(Color.Design.aiPurple)
                    .padding(6)
            }
        }
    }

    // MARK: - Account sheet

    private func accountSheet(isToAccount: Bool) -> some View {
        let currentId = isToAccount ? store.toAccountId : store.accountId
        let candidates: [Account] = isToAccount
            ? store.accounts.filter { $0.id != store.accountId }
            : store.accounts

        return NavigationStack {
            ZStack {
                WarmGradientBackground(variant: .center)
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(candidates) { account in
                            Button {
                                if isToAccount {
                                    store.send(.toAccountSelected(account.id))
                                } else {
                                    store.send(.accountSelected(account.id))
                                }
                                activeSheet = nil
                            } label: {
                                accountRow(account: account, isSelected: currentId == account.id)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle(Text(String(localized: isToAccount ? "add_transaction_to" : "add_transaction_account")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common_cancel")) { activeSheet = nil }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func accountRow(account: Account, isSelected: Bool) -> some View {
        let tint = Color.Design.fromHex(account.color)
        return HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous).fill(tint.opacity(0.18))
                Image(systemName: account.icon)
                    .font(Font.Design.size18Medium)
                    .foregroundStyle(tint)
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 1) {
                Text(account.name)
                    .font(Font.Design.size15Medium)
                    .foregroundStyle(Color.Design.textPrimary)
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(Font.Design.size20)
                    .foregroundStyle(tint)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isSelected ? tint.opacity(0.10) : Color.Design.surface.opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isSelected ? tint.opacity(0.5) : Color.clear, lineWidth: 1)
        )
    }

    // MARK: - Date sheet

    private var dateSheet: some View {
        NavigationStack {
            ZStack {
                WarmGradientBackground(variant: .center)
                VStack {
                    DatePicker(
                        "",
                        selection: $store.date,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .padding(.horizontal, 16)
                    Spacer()
                }
                .padding(.top, 8)
            }
            .navigationTitle(Text(String(localized: "add_transaction_date")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common_save")) { activeSheet = nil }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
