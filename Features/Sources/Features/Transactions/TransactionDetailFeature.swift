import ComposableArchitecture
import Domain
import Foundation

@Reducer
public struct TransactionDetailFeature: Sendable {
    public init() {}

    // MARK: - State

    @ObservableState
    public struct State: Equatable {
        public var transaction: Transaction
        public var categoryName: String?
        public var accountName: String?
        public var toAccountName: String?

        @Presents var editTransaction: AddTransactionFeature.State?
        var showDeleteConfirmation: Bool = false

        public init(transaction: Transaction) {
            self.transaction = transaction
        }
    }

    // MARK: - Action

    public enum Action: Sendable, Equatable {
        case task
        case namesLoaded(accountName: String?, toAccountName: String?, categoryName: String?)

        case editTapped
        case deleteTapped
        case deleteConfirmed
        case deleteCancelled
        case dismiss

        case editTransaction(PresentationAction<AddTransactionFeature.Action>)

        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Sendable, Equatable {
            case deleted(Transaction.ID)
            case updated(Transaction)
        }
    }

    // MARK: - Dependencies

    @Dependency(\.transactionClient) var transactionClient
    @Dependency(\.accountClient) var accountClient
    @Dependency(\.categoryClient) var categoryClient
    @Dependency(\.dismiss) var dismiss

    // MARK: - Body

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                let accountId = state.transaction.accountId
                let toAccountId = state.transaction.toAccountId
                let categoryId = state.transaction.categoryId
                return .run { send in
                    async let accounts = accountClient.fetchAll()
                    async let categories = categoryClient.fetchAll()
                    let (a, c) = try await (accounts, categories)
                    let accountName = a.first { $0.id == accountId }?.name
                    let toAccountName = toAccountId.flatMap { id in a.first { $0.id == id }?.name }
                    let categoryName = categoryId.flatMap { id in c.first { $0.id == id }?.name }
                    await send(.namesLoaded(accountName: accountName, toAccountName: toAccountName, categoryName: categoryName))
                }

            case let .namesLoaded(accountName, toAccountName, categoryName):
                state.accountName = accountName
                state.toAccountName = toAccountName
                state.categoryName = categoryName
                return .none

            case .editTapped:
                state.editTransaction = AddTransactionFeature.State(mode: .edit(state.transaction))
                return .none

            case .deleteTapped:
                state.showDeleteConfirmation = true
                return .none

            case .deleteCancelled:
                state.showDeleteConfirmation = false
                return .none

            case .deleteConfirmed:
                state.showDeleteConfirmation = false
                let id = state.transaction.id
                return .run { send in
                    try await transactionClient.delete(id)
                    await send(.delegate(.deleted(id)))
                    await dismiss()
                }

            case .dismiss:
                return .run { _ in await dismiss() }

            case let .editTransaction(.presented(.delegate(.saved))):
                state.editTransaction = nil
                return .none

            case .editTransaction(.presented(.delegate(.dismissed))):
                state.editTransaction = nil
                return .none

            case .editTransaction:
                return .none

            case .delegate:
                return .none
            }
        }
        .ifLet(\.$editTransaction, action: \.editTransaction) {
            AddTransactionFeature()
        }
    }
}
