import Testing
import Foundation
import ComposableArchitecture
@testable import Features
import Domain

@Suite("TransactionsFeature Tests")
struct TransactionsFeatureTests {

    static let sampleTransaction = Transaction(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        amount: 200,
        date: Date(timeIntervalSince1970: 1_000_000),
        note: "午餐",
        categoryId: nil,
        accountId: UUID(),
        toAccountId: nil,
        type: .expense,
        tags: [],
        aiSuggested: false,
        createdAt: Date(timeIntervalSince1970: 1_000_000),
        updatedAt: Date(timeIntervalSince1970: 1_000_000)
    )

    // MARK: - .task

    @Test(".task loads transactions and updates state")
    func testTaskLoadsTransactions() async {
        let store = await TestStore(initialState: TransactionsFeature.State()) {
            TransactionsFeature()
        } withDependencies: {
            $0.transactionClient.fetchAll = { [Self.sampleTransaction] }
        }

        await store.send(.task) {
            $0.isLoading = true
        }
        await store.receive(\.transactionsLoaded) {
            $0.isLoading = false
            $0.transactions = [Self.sampleTransaction]
        }
    }

    // MARK: - Search

    @Test("searchTextChanged updates searchText in state")
    func testSearchTextChanged() async {
        let store = await TestStore(initialState: TransactionsFeature.State()) {
            TransactionsFeature()
        } withDependencies: {
            $0.transactionClient.fetchAll = { [] }
            $0.transactionClient.search = { _ in [Self.sampleTransaction] }
        }
        store.exhaustivity = .off

        await store.send(.searchTextChanged("午餐")) {
            $0.searchText = "午餐"
        }
    }

    @Test("searchTextChanged with empty text triggers fetchAll")
    func testSearchTextChangedEmptyFetchesAll() async {
        var initialState = TransactionsFeature.State()
        initialState.searchText = "午餐"

        let store = await TestStore(initialState: initialState) {
            TransactionsFeature()
        } withDependencies: {
            $0.transactionClient.fetchAll = { [Self.sampleTransaction] }
        }

        await store.send(.searchTextChanged("")) {
            $0.searchText = ""
        }
        await store.receive(\.transactionsLoaded) {
            $0.transactions = [Self.sampleTransaction]
        }
    }

    // MARK: - Filter

    @Test("filterButtonTapped opens filter sheet with current activeFilter")
    func testFilterButtonTappedOpensSheet() async {
        let store = await TestStore(initialState: TransactionsFeature.State()) {
            TransactionsFeature()
        } withDependencies: {
            $0.transactionClient.fetchAll = { [] }
            $0.categoryClient.fetchAll = { [] }
            $0.accountClient.fetchAll = { [] }
            $0.tagClient.fetchAll = { [] }
        }
        store.exhaustivity = .off

        await store.send(.filterButtonTapped) {
            $0.filter = FilterFeature.State(initialFilter: TransactionFilter())
        }
    }

    @Test("filter delegate filterApplied updates activeFilter and reloads")
    func testFilterAppliedUpdatesActiveFilter() async {
        let filter = TransactionFilter(types: [.expense])

        var initialState = TransactionsFeature.State()
        initialState.filter = FilterFeature.State(initialFilter: TransactionFilter())

        let store = await TestStore(initialState: initialState) {
            TransactionsFeature()
        } withDependencies: {
            $0.transactionClient.fetch = { _ in [] }
        }

        await store.send(.filter(.presented(.delegate(.filterApplied(filter))))) {
            $0.activeFilter = filter
        }
        await store.receive(\.transactionsLoaded)
    }

    // MARK: - Delete

    @Test("deleteTransaction sets deleteConfirmationId")
    func testDeleteTransactionSetsConfirmation() async {
        var initialState = TransactionsFeature.State()
        initialState.transactions = [Self.sampleTransaction]

        let store = await TestStore(initialState: initialState) {
            TransactionsFeature()
        } withDependencies: {
            $0.transactionClient.fetchAll = { [Self.sampleTransaction] }
        }
        store.exhaustivity = .off

        await store.send(.deleteTransaction(Self.sampleTransaction.id)) {
            $0.deleteConfirmationId = Self.sampleTransaction.id
        }
    }

    @Test("deleteCancelled clears deleteConfirmationId")
    func testDeleteCancelledClearsConfirmation() async {
        var initialState = TransactionsFeature.State()
        initialState.deleteConfirmationId = Self.sampleTransaction.id

        let store = await TestStore(initialState: initialState) {
            TransactionsFeature()
        }

        await store.send(.deleteCancelled) {
            $0.deleteConfirmationId = nil
        }
    }

    @Test("deleteConfirmed removes transaction from state")
    func testDeleteConfirmedRemovesTransaction() async {
        var initialState = TransactionsFeature.State()
        initialState.transactions = [Self.sampleTransaction]
        initialState.deleteConfirmationId = Self.sampleTransaction.id

        let store = await TestStore(initialState: initialState) {
            TransactionsFeature()
        } withDependencies: {
            $0.ledger.delete = { _ in }
            $0.transactionClient.fetchAll = { [Self.sampleTransaction] }
        }

        await store.send(.deleteConfirmed) {
            $0.deleteConfirmationId = nil
        }
        await store.receive(\.transactionDeleted) {
            $0.transactions = []
        }
    }

    // MARK: - Transaction Tapped

    @Test("transactionTapped presents detail sheet")
    func testTransactionTappedPresentsDetail() async {
        let store = await TestStore(initialState: TransactionsFeature.State()) {
            TransactionsFeature()
        } withDependencies: {
            $0.transactionClient.fetchAll = { [] }
            $0.transactionClient.fetch = { _ in [] }
            $0.categoryClient.fetchAll = { [] }
            $0.accountClient.fetchAll = { [] }
            $0.tagClient.fetchAll = { [] }
        }
        store.exhaustivity = .off

        await store.send(.transactionTapped(Self.sampleTransaction)) {
            $0.detail = TransactionDetailFeature.State(transaction: Self.sampleTransaction)
        }
    }

    // MARK: - Context Action

    @Test("contextActionTapped presents addTransaction sheet in .add(.expense) mode")
    @MainActor
    func testContextActionTappedPresentsAddTransaction() async {
        let store = await TestStore(initialState: TransactionsFeature.State()) {
            TransactionsFeature()
        }
        store.exhaustivity = .off

        // TransactionsFeature uses Date() directly (no date dependency), so we only verify
        // that the sheet is presented with the correct mode.
        await store.send(.contextActionTapped)
        #expect(store.state.addTransaction?.mode == .add(.expense))
        #expect(store.state.addTransaction?.type == .expense)
    }
}
