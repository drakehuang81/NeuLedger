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

        // Loaded options
        public var accounts: [Account]
        public var categories: [Domain.Category]
        public var isLoading: Bool

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

        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Sendable, Equatable {
            case saved
            case dismissed
        }
    }

    // MARK: - Dependencies

    @Dependency(\.accountClient) var accountClient
    @Dependency(\.categoryClient) var categoryClient
    @Dependency(\.transactionClient) var transactionClient
    @Dependency(\.dismiss) var dismiss

    private enum CancelID { case task }

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
                    state.accountId = accounts.first?.id
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
                return .none

            case let .toAccountSelected(id):
                state.toAccountId = id
                return .none

            case let .categorySelected(id):
                state.categoryId = id
                state.categoryError = nil
                return .none

            case let .noteChanged(note):
                state.note = note
                return .none

            case let .dateChanged(date):
                state.date = date
                return .none

            case .saveTapped:
                var hasError = false

                let amountValue = Decimal(string: state.amountText) ?? 0
                if amountValue <= 0 {
                    state.amountError = "請輸入有效金額"
                    hasError = true
                }

                if state.accountId == nil {
                    state.accountError = "請選擇帳戶"
                    hasError = true
                }

                if state.type != .transfer && state.categoryId == nil {
                    state.categoryError = "請選擇分類"
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
                    }
                    await send(.savedSuccessfully)
                }

            case .savedSuccessfully:
                return .run { send in
                    await send(.delegate(.saved))
                    await dismiss()
                }

            case .dismiss:
                return .run { send in
                    await send(.delegate(.dismissed))
                    await dismiss()
                }

            case .delegate:
                return .none
            }
        }
    }
}
