import ComposableArchitecture
import Domain
import Foundation

@Reducer
public struct AddTransactionFeature: Sendable {
    public init() {}

    // MARK: - Mode

    public enum Mode: Equatable, Sendable {
        case add(TransactionType)
        case edit(Transaction)
        case addPrefilled(ExtractedTransaction)   // opened from TabBar AI input with pre-parsed data
    }

    // MARK: - State

    @ObservableState
    public struct State: Equatable {
        public var mode: Mode

        // Form fields
        public var type: TransactionType
        public var amountText: String
        public var accountId: Account.ID?
        public var toAccountId: Account.ID?
        public var categoryId: Domain.Category.ID?
        public var note: String
        public var date: Date

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
            }
        }

        var filteredCategories: [Domain.Category] {
            categories.filter { $0.type == type }
        }
    }

    // MARK: - Action

    public enum Action: Sendable, Equatable {
        case task
        case optionsLoaded(accounts: [Account], categories: [Domain.Category])

        case typeChanged(TransactionType)
        case amountTextChanged(String)
        case accountSelected(Account.ID?)
        case toAccountSelected(Account.ID?)
        case categorySelected(Domain.Category.ID?)
        case noteChanged(String)
        case dateChanged(Date)

        case saveTapped
        case dismiss
        case savedSuccessfully
        case savedSuccessfullyWithTransaction(Transaction)

        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Sendable, Equatable {
            case saved                              // add / addPrefilled mode
            case savedWithTransaction(Transaction)  // edit mode
            case dismissed
        }

        // AI assistance actions
        case backgroundExtractionCompleted(ExtractedTransaction?)
        case suggestCategoryTapped
        case categorySuggestionsReceived(TaskResult<CategorySuggestions>)
    }

    // MARK: - Dependencies

    @Dependency(\.accountClient) var accountClient
    @Dependency(\.categoryClient) var categoryClient
    @Dependency(\.transactionClient) var transactionClient
    @Dependency(\.userSettingsClient) var userSettingsClient
    @Dependency(\.dismiss) var dismiss
    @Dependency(\.aiServiceClient) var aiServiceClient

    private enum CancelID { case task; case noteDebounce; case categorySuggest }

    // MARK: - Body

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                state.isLoading = true
                return .run { send in
                    async let accounts = accountClient.fetchActive()
                    async let categories = categoryClient.fetchAll()
                    let (a, c) = try await (accounts, categories)
                    await send(.optionsLoaded(accounts: a, categories: c))
                }
                .cancellable(id: CancelID.task)

            case let .optionsLoaded(accounts, categories):
                state.isLoading = false
                state.accounts = accounts
                state.categories = categories
                if case .add = state.mode, state.accountId == nil {
                    let defaultId = userSettingsClient.string(.defaultAccountId)
                    if !defaultId.isEmpty,
                       let match = accounts.first(where: { $0.id.uuidString == defaultId }) {
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

            case let .amountTextChanged(text):
                state.amountText = text
                state.amountError = nil
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

            case let .noteChanged(note):
                state.note = note
                state.isBackgroundParsingNote = !note.isEmpty
                guard !note.isEmpty else {
                    // Cancel any pending debounce when field is cleared
                    return .cancel(id: CancelID.noteDebounce)
                }
                // Debounce 500ms — consistent with RunLoop.main pattern used in TransactionsFeature.
                // isAvailable() is checked inline (not via stored flag) because AddTransactionFeature
                // has no .task lifecycle, and adding one just for this check would be over-engineering.
                return .run { [note] send in
                    guard aiServiceClient.isAvailable(), userSettingsClient.bool(.aiEnabled) else {
                        await send(.backgroundExtractionCompleted(nil))
                        return
                    }
                    let result = try? await aiServiceClient.extractTransaction(note)
                    await send(.backgroundExtractionCompleted(result))
                }
                .debounce(id: CancelID.noteDebounce, for: .milliseconds(500), scheduler: RunLoop.main)

            case let .dateChanged(date):
                state.date = date
                return .none

            case .saveTapped:
                var hasError = false

                let amountValue = Decimal(string: state.amountText) ?? 0
                if amountValue <= 0 {
                    state.amountError = String(localized: "add_transaction_error_amount")
                    hasError = true
                }

                if state.accountId == nil {
                    state.accountError = String(localized: "add_transaction_error_account")
                    hasError = true
                }

                if state.type != .transfer && state.categoryId == nil {
                    if case .edit = state.mode {
                        // In edit mode, allow saving with no category (preserving existing nil)
                    } else {
                        state.categoryError = String(localized: "add_transaction_error_category")
                        hasError = true
                    }
                }

                if state.type == .transfer && state.accountId != nil && state.accountId == state.toAccountId {
                    state.transferError = String(localized: "add_transaction_error_same_account")
                    hasError = true
                }

                if hasError { return .none }

                let mode = state.mode
                let date = state.date
                let note = state.note.isEmpty ? Optional<String>.none : state.note
                let categoryId = state.categoryId
                let accountId = state.accountId!
                let toAccountId = state.toAccountId
                let type_ = state.type

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
                        try await transactionClient.add(transaction)

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
                        try await transactionClient.update(transaction)
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
                        try await transactionClient.add(transaction)
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
                return .run { send in
                    await send(.delegate(.dismissed))
                    await dismiss()
                }

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
                guard aiServiceClient.isAvailable(), userSettingsClient.bool(.aiEnabled) else {
                    state.categorySuggestionError = "此裝置不支援 AI 功能"
                    return .none
                }
                state.isSuggestingCategory = true
                state.categorySuggestionError = nil
                let description = state.note
                let categoryNames = state.filteredCategories.map(\.name)
                return .run { send in
                    await send(.categorySuggestionsReceived(
                        TaskResult { try await aiServiceClient.suggestCategories(description, categoryNames) }
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
                state.categorySuggestionError = "無法取得建議，請手動選擇"
                return .none
            }
        }
    }
}
