import ComposableArchitecture
import Domain
import Foundation

@Reducer
public struct TransactionsFeature: Sendable {
    public init() {}

    // MARK: - State

    @ObservableState
    public struct State: Equatable {
        public var transactions: [Transaction] = []
        public var searchText: String = ""
        public var activeFilter: TransactionFilter = TransactionFilter()
        public var isLoading: Bool = false
        public var deleteConfirmationId: Transaction.ID? = nil

        @Presents var detail: TransactionDetailFeature.State?
        @Presents var filter: FilterFeature.State?
        @Presents var addTransaction: AddTransactionFeature.State?

        public init() {}

        var hasActiveFilters: Bool {
            activeFilter.categoryIds != nil ||
            activeFilter.accountIds != nil ||
            activeFilter.tagIds != nil ||
            activeFilter.types != nil ||
            activeFilter.dateRange != nil
        }

        var activeFilterCount: Int {
            [
                activeFilter.categoryIds.map { _ in 1 } ?? 0,
                activeFilter.accountIds.map { _ in 1 } ?? 0,
                activeFilter.tagIds.map { _ in 1 } ?? 0,
                activeFilter.types.map { _ in 1 } ?? 0,
                activeFilter.dateRange.map { _ in 1 } ?? 0
            ].reduce(0, +)
        }
    }

    // MARK: - Action

    public enum Action: Sendable, Equatable {
        case task
        case transactionsLoaded([Transaction])

        case searchTextChanged(String)
        case searchDebounced

        case filterButtonTapped
        case contextActionTapped

        case transactionTapped(Transaction)
        case deleteTransaction(Transaction.ID)
        case deleteConfirmed
        case deleteCancelled
        case transactionDeleted(Transaction.ID)

        case detail(PresentationAction<TransactionDetailFeature.Action>)
        case filter(PresentationAction<FilterFeature.Action>)
        case addTransaction(PresentationAction<AddTransactionFeature.Action>)
    }

    // MARK: - Dependencies

    @Dependency(\.transactionClient) var transactionClient

    private enum CancelID {
        case task
        case search
    }

    // MARK: - Body

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            // MARK: Lifecycle
            case .task:
                state.isLoading = true
                return .run { send in
                    let transactions = try await transactionClient.fetchAll()
                    await send(.transactionsLoaded(transactions))
                }
                .cancellable(id: CancelID.task)

            case let .transactionsLoaded(transactions):
                state.isLoading = false
                state.transactions = transactions.sorted { $0.date > $1.date }
                return .none

            // MARK: Search
            case let .searchTextChanged(text):
                state.searchText = text
                if text.isEmpty {
                    return .run { send in
                        let transactions = try await transactionClient.fetchAll()
                        await send(.transactionsLoaded(transactions))
                    }
                    .cancellable(id: CancelID.search, cancelInFlight: true)
                }
                return .run { send in
                    await send(.searchDebounced)
                }
                .debounce(id: CancelID.search, for: 0.3, scheduler: RunLoop.main)

            case .searchDebounced:
                let text = state.searchText
                return .run { send in
                    let results = try await transactionClient.search(text)
                    await send(.transactionsLoaded(results))
                }

            // MARK: Filter
            case .filterButtonTapped:
                state.filter = FilterFeature.State(initialFilter: state.activeFilter)
                return .none

            case let .filter(.presented(.delegate(.filterApplied(newFilter)))):
                state.activeFilter = newFilter
                return .run { [filter = newFilter] send in
                    let results = try await transactionClient.fetch(filter)
                    await send(.transactionsLoaded(results))
                }

            case .filter(.presented(.delegate(.dismissed))):
                state.filter = nil
                return .none

            case .filter:
                return .none

            // MARK: Context action (add transaction from tab bar)
            case .contextActionTapped:
                state.addTransaction = AddTransactionFeature.State(mode: .add(.expense))
                return .none

            // MARK: Transaction interactions
            case let .transactionTapped(transaction):
                state.detail = TransactionDetailFeature.State(transaction: transaction)
                return .none

            case let .deleteTransaction(id):
                state.deleteConfirmationId = id
                return .none

            case .deleteConfirmed:
                guard let id = state.deleteConfirmationId else { return .none }
                state.deleteConfirmationId = nil
                return .run { send in
                    try await transactionClient.delete(id)
                    await send(.transactionDeleted(id))
                }

            case .deleteCancelled:
                state.deleteConfirmationId = nil
                return .none

            case let .transactionDeleted(id):
                state.transactions.removeAll { $0.id == id }
                return .none

            // MARK: Detail
            case let .detail(.presented(.delegate(.deleted(id)))):
                state.transactions.removeAll { $0.id == id }
                state.detail = nil
                return .none

            case .detail(.presented(.delegate(.updated))):
                state.detail = nil
                return .run { send in
                    let transactions = try await transactionClient.fetchAll()
                    await send(.transactionsLoaded(transactions))
                }

            case .detail(.dismiss):
                state.detail = nil
                return .none

            case .detail:
                return .none

            // MARK: AddTransaction
            case .addTransaction(.presented(.delegate(.saved))):
                state.addTransaction = nil
                return .run { send in
                    let transactions = try await transactionClient.fetchAll()
                    await send(.transactionsLoaded(transactions))
                }

            case .addTransaction(.presented(.delegate(.dismissed))):
                state.addTransaction = nil
                return .none

            case .addTransaction:
                return .none
            }
        }
        .ifLet(\.$detail, action: \.detail) {
            TransactionDetailFeature()
        }
        .ifLet(\.$filter, action: \.filter) {
            FilterFeature()
        }
        .ifLet(\.$addTransaction, action: \.addTransaction) {
            AddTransactionFeature()
        }
    }
}
