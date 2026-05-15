import ComposableArchitecture
import Domain
import Foundation

@Reducer
public struct TransactionDetailFeature: Sendable {
    public init() {}

    /// Equatable wrapper for the SwiftUI `PresentationDetent` we expose
    /// to the View — keeps Feature layer free of SwiftUI imports.
    public enum Detent: Equatable, Sendable {
        case medium
        case large
    }

    // MARK: - State

    @ObservableState
    public struct State: Equatable {
        public var transaction: Transaction
        public var categoryName: String?
        public var accountName: String?
        public var toAccountName: String?
        public var account: Account?
        public var toAccount: Account?
        public var insight: TransactionInsight?
        public var detent: Detent = .medium
        public var pendingDelete: Bool = false

        @Presents var editTransaction: AddTransactionFeature.State?
        var showDeleteConfirmation: Bool = false

        public init(transaction: Transaction) {
            self.transaction = transaction
        }
    }

    // MARK: - Action

    public enum Action: Sendable, Equatable {
        case task
        case namesLoaded(
            accountName: String?,
            toAccountName: String?,
            categoryName: String?,
            account: Account?,
            toAccount: Account?
        )
        case insightLoaded(TransactionInsight)
        case insightFailed

        case detentChanged(Detent)

        case editTapped
        case deleteTapped
        case deleteConfirmed
        case deleteCancelled
        case undoTapped
        case deleteWindowExpired
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
    @Dependency(\.continuousClock) var clock
    @Dependency(\.dismiss) var dismiss

    private enum CancelID: Hashable { case deleteWindow }

    // MARK: - Body

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                let txn = state.transaction
                return .merge(
                    .run { send in
                        async let accounts = accountClient.fetchAll()
                        async let categories = categoryClient.fetchAll()
                        let (a, c) = try await (accounts, categories)
                        let account = a.first { $0.id == txn.accountId }
                        let toAccount = txn.toAccountId.flatMap { id in a.first { $0.id == id } }
                        let categoryName = txn.categoryId.flatMap { id in c.first { $0.id == id }?.name }
                        await send(.namesLoaded(
                            accountName: account?.name,
                            toAccountName: toAccount?.name,
                            categoryName: categoryName,
                            account: account,
                            toAccount: toAccount
                        ))
                    },
                    .run { send in
                        do {
                            let insight = try await transactionClient.detailStats(txn)
                            await send(.insightLoaded(insight))
                        } catch {
                            await send(.insightFailed)
                        }
                    }
                )

            case let .namesLoaded(accountName, toAccountName, categoryName, account, toAccount):
                state.accountName = accountName
                state.toAccountName = toAccountName
                state.categoryName = categoryName
                state.account = account
                state.toAccount = toAccount
                return .none

            case let .insightLoaded(insight):
                state.insight = insight
                return .none

            case .insightFailed:
                state.insight = nil
                return .none

            case let .detentChanged(detent):
                state.detent = detent
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
                state.pendingDelete = true
                return .run { send in
                    try await clock.sleep(for: .seconds(5))
                    await send(.deleteWindowExpired)
                }
                .cancellable(id: CancelID.deleteWindow, cancelInFlight: true)

            case .undoTapped:
                state.pendingDelete = false
                return .cancel(id: CancelID.deleteWindow)

            case .deleteWindowExpired:
                state.pendingDelete = false
                let id = state.transaction.id
                return .run { send in
                    try await transactionClient.delete(id)
                    await send(.delegate(.deleted(id)))
                    await dismiss()
                }

            case .dismiss:
                return .run { _ in await dismiss() }

            case let .editTransaction(.presented(.delegate(.savedWithTransaction(t)))):
                state.transaction = t
                state.editTransaction = nil
                return .send(.delegate(.updated(t)))

            case .editTransaction(.presented(.delegate(.saved))):
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
