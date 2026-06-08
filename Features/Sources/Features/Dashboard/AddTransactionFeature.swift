import ComposableArchitecture
import Domain
import Foundation
import Common

@Reducer
public struct AddTransactionFeature: Sendable {
    public init() {}

    // MARK: - Mode

    public enum Mode: Equatable, Sendable {
        case add(TransactionType)
        case edit(Transaction)
        case addPrefilled(ExtractedTransaction)          // opened from TabBar AI input with pre-parsed data
        case addRecurringConfirmation(RecurringTransaction)  // confirm a due recurring template
    }

    // MARK: - State

    @ObservableState
    public struct State: Equatable, Sendable {
        public var mode: Mode

        // Form fields
        public var type: TransactionType
        public var amountText: String
        public var accountId: Account.ID?
        public var toAccountId: Account.ID?
        public var categoryId: Domain.Category.ID?
        public var note: String
        public var date: Date
        public var recurringFrequency: BudgetPeriod? = nil   // nil = not recurring

        // Validation errors
        public var amountError: String?
        public var accountError: String?
        public var categoryError: String?
        public var transferError: String?

        // Loaded options
        public var accounts: [Account]
        public var categories: [Domain.Category]
        public var isLoading: Bool

        // AI assistance state
        public var isBackgroundParsingNote: Bool = false
        public var isSuggestingCategory: Bool = false
        public var suggestedCategoryNames: [String] = []
        public var categorySuggestionError: String? = nil

        // Voice recording state
        public var isRecording: Bool = false
        public var speechError: String? = nil
        var noteBeforeRecording: String = ""   // saves note prefix at recording start

        public init(mode: Mode = .add(.expense), date: Date = Date()) {
            self.mode = mode
            self.accounts = []
            self.categories = []
            self.isLoading = false

            switch mode {
            case let .add(type):
                self.type = type
                self.amountText = ""
                self.accountId = nil
                self.toAccountId = nil
                self.categoryId = nil
                self.note = ""
                self.date = date

            case let .edit(transaction):
                self.type = transaction.type
                self.amountText = transaction.amount.formatted(.number.precision(.fractionLength(0)))
                self.accountId = transaction.accountId
                self.toAccountId = transaction.toAccountId
                self.categoryId = transaction.categoryId
                self.note = transaction.note ?? ""
                self.date = transaction.date

            case let .addPrefilled(extracted):
                // Map optional AI-parsed fields to form state; use sensible defaults for nil values.
                self.type = TransactionType(rawValue: extracted.type ?? "") ?? .expense
                self.amountText = extracted.amount.map { String($0) } ?? ""
                self.note = extracted.description ?? ""
                self.accountId = nil     // user must always select their own account
                self.toAccountId = nil
                self.categoryId = nil    // category matching handled separately via suggestCategoryTapped
                self.date = date

            case let .addRecurringConfirmation(template):
                self.type = template.type
                self.amountText = template.amount.formatted(.number.precision(.fractionLength(0)))
                self.accountId = template.accountId
                self.toAccountId = template.toAccountId
                self.categoryId = template.categoryId
                self.note = template.note ?? ""
                self.date = date
            }
        }

        var filteredCategories: [Domain.Category] {
            categories.filter { $0.type == type }
        }
    }

    // MARK: - Action

    public enum Action: Sendable, BindableAction, Equatable {
        case binding(BindingAction<State>)
        case task
        case optionsLoaded(accounts: [Account], categories: [Domain.Category])

        case typeChanged(TransactionType)
        case accountSelected(Account.ID?)
        case toAccountSelected(Account.ID?)
        case categorySelected(Domain.Category.ID?)

        case recurringToggled(Bool)
        case recurringFrequencyChanged(BudgetPeriod)

        case saveTapped
        case dismiss
        case savedSuccessfully
        case savedSuccessfullyWithTransaction(Transaction)

        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Sendable, Equatable {
            case saved                                                  // add / addPrefilled mode
            case savedWithTransaction(Transaction)                      // edit mode
            case savedRecurringConfirmation(RecurringTransaction.ID, Date) // addRecurringConfirmation mode
            case dismissed
        }

        // AI assistance actions
        case backgroundExtractionCompleted(ExtractedTransaction?)
        case suggestCategoryTapped
        case categorySuggestionsReceived(TaskResult<CategorySuggestions>)

        // Voice recording actions
        case recordingTapped
        case transcriptionUpdated(String)   // full transcript so far (not a delta)
        case transcriptionFailed
        case recordingPermissionResult(Bool)   // internal: bridges async permission check to state
    }

    // MARK: - Dependencies

    @Dependency(\.ledgerClient) var ledger
    @Dependency(\.dismiss) var dismiss
    @Dependency(\.captureClient) var captureClient

    private enum CancelID { case task; case noteDebounce; case categorySuggest; case speechRecording }

    // MARK: - Body

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding(\.amountText):
                state.amountError = nil
                return .none

            case .binding(\.note):
                state.isBackgroundParsingNote = !state.note.isEmpty
                guard !state.note.isEmpty else {
                    return .cancel(id: CancelID.noteDebounce)
                }
                let note = state.note
                return .run { send in
                    guard captureClient.isAvailable() else {
                        await send(.backgroundExtractionCompleted(nil))
                        return
                    }
                    let result = try? await captureClient.extractFromText(note)
                    await send(.backgroundExtractionCompleted(result))
                }
                .debounce(id: CancelID.noteDebounce, for: .milliseconds(500), scheduler: RunLoop.main)

            case .binding:
                return .none

            case .task:
                state.isLoading = true
                return .run { send in
                    async let accounts = ledger.listActiveAccounts()
                    async let categories = ledger.listCategories(nil)
                    let (a, c) = try await (accounts, categories)
                    await send(.optionsLoaded(accounts: a, categories: c))
                }
                .cancellable(id: CancelID.task)

            case let .optionsLoaded(accounts, categories):
                state.isLoading = false
                state.accounts = accounts
                state.categories = categories
                if case .add = state.mode, state.accountId == nil {
                    if let defaultId = ledger.defaultAccountId(),
                       let match = accounts.first(where: { $0.id == defaultId }) {
                        state.accountId = match.id
                    } else {
                        state.accountId = accounts.first?.id
                    }
                }
                return .none

            case let .typeChanged(type):
                state.type = type
                state.categoryId = nil
                return .none

            case let .accountSelected(id):
                state.accountId = id
                state.accountError = nil
                state.transferError = nil
                return .none

            case let .toAccountSelected(id):
                state.toAccountId = id
                state.transferError = nil
                return .none

            case let .categorySelected(id):
                state.categoryId = id
                state.categoryError = nil
                return .none

            case let .recurringToggled(isOn):
                state.recurringFrequency = isOn ? .monthly : nil
                return .none

            case let .recurringFrequencyChanged(frequency):
                state.recurringFrequency = frequency
                return .none

            case .saveTapped:
                var hasError = false

                let amountValue = state.amountText.parsedAmountDecimal ?? 0
                if amountValue <= 0 {
                    state.amountError = String(localized: "add_transaction_error_amount")
                    hasError = true
                }

                if state.accountId == nil {
                    state.accountError = String(localized: "add_transaction_error_account")
                    hasError = true
                }
                switch state.type {
                case .transfer:
                    if state.accountId != nil && state.accountId == state.toAccountId {
                        state.transferError = String(localized: "add_transaction_error_same_account")
                        hasError = true
                    }
                case .income, .expense:
                    if state.categoryId == nil {
                        if case .edit = state.mode {
                            // In edit mode, allow saving with no category (preserving existing nil)
                        } else {
                            state.categoryError = String(localized: "add_transaction_error_category")
                            hasError = true
                        }
                    }
                }

                if hasError { return .none }

                let mode = state.mode
                let date = state.date
                let note = state.note.isEmpty ? Optional<String>.none : state.note
                let categoryId = state.categoryId
                let accountId = state.accountId!
                let toAccountId = state.toAccountId
                let type_ = state.type
                let recurringFrequency_ = state.recurringFrequency

                return .run { send in
                    switch mode {
                    case .add:
                        let transaction = Transaction(
                            amount: amountValue,
                            date: date,
                            note: note,
                            categoryId: categoryId,
                            accountId: accountId,
                            toAccountId: toAccountId,
                            type: type_
                        )
                        try await ledger.record(transaction)
                        if let frequency = recurringFrequency_ {
                            let templateId = UUID()
                            let nextDue: Date
                            switch frequency {
                            case .weekly:  nextDue = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: date) ?? date
                            case .monthly: nextDue = Calendar.current.date(byAdding: .month, value: 1, to: date) ?? date
                            case .yearly:  nextDue = Calendar.current.date(byAdding: .year, value: 1, to: date) ?? date
                            }
                            let template = RecurringTransaction(
                                id: templateId,
                                amount: amountValue,
                                note: note,
                                categoryId: categoryId,
                                accountId: accountId,
                                toAccountId: toAccountId,
                                type: type_,
                                tags: [],
                                frequency: frequency,
                                nextDueDate: nextDue,
                                isActive: true,
                                createdAt: date
                            )
                            try await ledger.createRecurring(template)
                        }

                    case let .edit(existing):
                        let transaction = Transaction(
                            id: existing.id,
                            amount: amountValue,
                            date: date,
                            note: note,
                            categoryId: categoryId,
                            accountId: accountId,
                            toAccountId: toAccountId,
                            type: type_,
                            tags: existing.tags,
                            aiSuggested: existing.aiSuggested,
                            createdAt: existing.createdAt,
                            updatedAt: Date()
                        )
                        try await ledger.update(transaction)
                        await send(.savedSuccessfullyWithTransaction(transaction))
                        return

                    case .addPrefilled:
                        // Pre-filled values were used for initial state only — saving works exactly like .add.
                        let transaction = Transaction(
                            amount: amountValue,
                            date: date,
                            note: note,
                            categoryId: categoryId,
                            accountId: accountId,
                            toAccountId: toAccountId,
                            type: type_
                        )
                        try await ledger.record(transaction)

                    case let .addRecurringConfirmation(template):
                        let transaction = Transaction(
                            amount: amountValue,
                            date: date,
                            note: note,
                            categoryId: categoryId,
                            accountId: accountId,
                            toAccountId: toAccountId,
                            type: type_
                        )
                        try await ledger.record(transaction)
                        let newNextDue = template.nextDate(after: template.nextDueDate)
                        await send(.delegate(.savedRecurringConfirmation(template.id, newNextDue)))
                        return
                    }
                    await send(.savedSuccessfully)
                }

            case .savedSuccessfully:
                return .run { send in
                    await send(.delegate(.saved))
                    await dismiss()
                }

            case let .savedSuccessfullyWithTransaction(transaction):
                return .run { send in
                    await send(.delegate(.savedWithTransaction(transaction)))
                    await dismiss()
                }

            case .dismiss:
                if state.isRecording {
                    state.isRecording = false
                    captureClient.stopVoiceSession()
                }
                return .concatenate(
                    .cancel(id: CancelID.speechRecording),
                    .run { send in
                        await send(.delegate(.dismissed))
                        await dismiss()
                    }
                )

            case .delegate:
                return .none

            case let .backgroundExtractionCompleted(extracted):
                // Always clear the loading indicator first.
                state.isBackgroundParsingNote = false
                guard let extracted else { return .none }

                // Apply AI-parsed values only to EMPTY form fields — never overwrite user input.
                // Note: state.note is intentionally NOT filled here. The debounce was triggered by
                // the user typing in the note field, so state.note is already set by noteChanged.
                // Filling it again from AI would produce a loop or conflict.
                if state.amountText.isEmpty, let amount = extracted.amount {
                    state.amountText = String(amount)
                }
                if state.categoryId == nil, let suggestedName = extracted.suggestedCategory {
                    // Match against the currently filtered categories list
                    state.categoryId = state.filteredCategories.first { $0.name == suggestedName }?.id
                }
                // Only update type for .add mode and only if the user hasn't manually changed it.
                // Skip for .addPrefilled (type was already set from AI in State.init).
                // Skip for .edit (preserve original transaction type).
                if case let .add(initialType) = state.mode,
                   state.type == initialType,
                   let typeString = extracted.type,
                   let parsedType = TransactionType(rawValue: typeString) {
                    state.type = parsedType
                    // Clear category if type changed (category list is filtered by type)
                    if parsedType != initialType { state.categoryId = nil }
                }
                return .none

            case .suggestCategoryTapped:
                // Guard in reducer — the View disables the button, but this prevents subtle bugs
                // if isAvailable state drifts between the .task check and the tap.
                guard captureClient.isAvailable() else {
                    state.categorySuggestionError = String(localized: "add_transaction_ai_unavailable")
                    return .none
                }
                state.isSuggestingCategory = true
                state.categorySuggestionError = nil
                let description = state.note
                let categoryNames = state.filteredCategories.map(\.name)
                return .run { send in
                    await send(.categorySuggestionsReceived(
                        TaskResult { try await captureClient.suggestCategories(description, categoryNames) }
                    ))
                }
                .cancellable(id: CancelID.categorySuggest, cancelInFlight: true)

            case let .categorySuggestionsReceived(.success(suggestions)):
                state.isSuggestingCategory = false
                // Filter to only names that exist in the current filtered category list
                state.suggestedCategoryNames = suggestions.suggestions.filter { name in
                    state.filteredCategories.contains { $0.name == name }
                }
                return .none

            case .categorySuggestionsReceived(.failure):
                state.isSuggestingCategory = false
                state.categorySuggestionError = String(localized: "add_transaction_category_suggestion_failed")
                return .none

            // MARK: - Voice recording

            case .recordingTapped:
                guard !state.isRecording else {
                    // Stop branch
                    state.isRecording = false
                    captureClient.stopVoiceSession()
                    return .cancel(id: CancelID.speechRecording)
                }
                // Start branch — check permission asynchronously
                return .run { send in
                    let granted = await captureClient.requestVoicePermission()
                    await send(.recordingPermissionResult(granted))
                }

            case let .recordingPermissionResult(granted):
                guard granted else {
                    state.speechError = String(localized: "speech_permission_denied_error")
                    return .none
                }
                // Capture note prefix once; overwritten at each new recording start.
                // Not reset on stop — always overwritten here, so stale state is safe.
                state.noteBeforeRecording = state.note
                state.isRecording = true
                state.speechError = nil
                return .run { send in
                    for try await text in captureClient.startVoiceSession() {
                        await send(.transcriptionUpdated(text))
                    }
                } catch: { _, send in
                    await send(.transcriptionFailed)
                }
                .cancellable(id: CancelID.speechRecording)

            case let .transcriptionUpdated(text):
                let prefix = state.noteBeforeRecording
                state.note = prefix.isEmpty ? text : prefix + " " + text
                return .none

            case .transcriptionFailed:
                state.isRecording = false
                state.speechError = String(localized: "speech_recognition_failed_error")
                // stream.finish(throwing:) does not release AVAudioEngine/AVAudioSession —
                // explicit stopVoiceSession() is required for hardware teardown.
                captureClient.stopVoiceSession()
                return .cancel(id: CancelID.speechRecording)
            }
        }
    }
}
