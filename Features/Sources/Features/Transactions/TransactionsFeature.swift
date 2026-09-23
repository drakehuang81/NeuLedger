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

        /// 最近一次載入或刪除失敗的訊息；成功載入後清空。View 用 SectionFailureView 顯示。
        public var loadError: String? = nil

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

        /// 列表查詢一律用這個：使用者的篩選條件 + 搜尋字串（health-audit A7：搜尋不再丟掉篩選）。
        var effectiveFilter: TransactionFilter {
            var filter = activeFilter
            filter.searchText = searchText.isEmpty ? nil : searchText
            return filter
        }

    }

    // MARK: - Action

    public enum Action: Sendable, Equatable {
        case task
        case transactionsLoaded([Transaction])
        case loadFailed(String)

        case searchTextChanged(String)
        case searchDebounced

        case filterButtonTapped
        case contextActionTapped
        // Received from MainTabFeature when the TabBar AI input successfully extracts a transaction.
        case addTransactionWithPrefilledData(ExtractedTransaction)

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

    @Dependency(\.ledgerClient) var ledger

    private enum CancelID {
        case load            // 所有列表查詢共用，cancelInFlight 避免舊查詢覆蓋新結果
        case searchDebounce  // 只給 debounce 用
    }

    /// 所有列表載入共用：成功 → transactionsLoaded，失敗 → loadFailed。
    private func reload(_ filter: TransactionFilter) -> Effect<Action> {
        .run { send in
            let rows = try await ledger.listAll(filter: filter)
            await send(.transactionsLoaded(rows.map(\.transaction)))
        } catch: { error, send in
            await send(.loadFailed(error.localizedDescription))
        }
        .cancellable(id: CancelID.load, cancelInFlight: true)
    }

    // MARK: - Body

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            // MARK: Lifecycle
            case .task:
                state.isLoading = true
                state.loadError = nil
                return reload(state.effectiveFilter)

            case let .transactionsLoaded(transactions):
                state.isLoading = false
                state.loadError = nil
                state.transactions = transactions.sorted { $0.date > $1.date }
                return .none

            case let .loadFailed(message):
                state.isLoading = false
                state.loadError = message
                return .none

            // MARK: Search
            case let .searchTextChanged(text):
                state.searchText = text
                if text.isEmpty {
                    return reload(state.effectiveFilter)
                }
                return .run { send in
                    await send(.searchDebounced)
                }
                .debounce(id: CancelID.searchDebounce, for: 0.3, scheduler: RunLoop.main)

            case .searchDebounced:
                return reload(state.effectiveFilter)

            // MARK: Filter
            case .filterButtonTapped:
                state.filter = FilterFeature.State(initialFilter: state.activeFilter)
                return .none

            case let .filter(.presented(.delegate(.filterApplied(newFilter)))):
                state.activeFilter = newFilter
                return reload(state.effectiveFilter)

            case .filter:
                return .none

            // MARK: Context action (add transaction from tab bar)
            case .contextActionTapped:
                state.addTransaction = AddTransactionFeature.State(mode: .add(.expense))
                return .none

            case let .addTransactionWithPrefilledData(extracted):
                state.addTransaction = AddTransactionFeature.State(mode: .addPrefilled(extracted))
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
                    try await ledger.delete(id)
                    await send(.transactionDeleted(id))
                } catch: { error, send in
                    await send(.loadFailed(error.localizedDescription))
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

            case let .detail(.presented(.delegate(.updated(t)))):
                if let idx = state.transactions.firstIndex(where: { $0.id == t.id }) {
                    state.transactions[idx] = t
                }
                state.detail = nil
                return .none

            case .detail(.dismiss):
                guard let detail = state.detail, detail.pendingDelete else {
                    state.detail = nil
                    return .none
                }
                // 使用者在 5 秒 Undo 視窗內關掉 sheet：child 的計時器會隨 ifLet 被取消，
                // 由 parent 立即提交刪除，避免「看起來刪了其實沒刪」（health-audit A2）。
                let id = detail.transaction.id
                state.detail = nil
                return .run { send in
                    try await ledger.delete(id)
                    await send(.transactionDeleted(id))
                } catch: { error, send in
                    await send(.loadFailed(error.localizedDescription))
                }

            case .detail:
                return .none

            // MARK: AddTransaction
            case .addTransaction(.presented(.delegate(.saved))):
                state.addTransaction = nil
                return reload(state.effectiveFilter)

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
