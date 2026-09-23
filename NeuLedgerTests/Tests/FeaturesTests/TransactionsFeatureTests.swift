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
        accountId: UUID().uuidString,
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
            $0.ledgerClient.listAll = { _ in [EnrichedTransaction(transaction: Self.sampleTransaction)] }
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
            $0.ledgerClient.listAll = { _ in [] }
            $0.ledgerClient.search = { _ in [EnrichedTransaction(transaction: Self.sampleTransaction)] }
        }
        await MainActor.run {
            store.exhaustivity = .off
        }

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
            $0.ledgerClient.listAll = { _ in [EnrichedTransaction(transaction: Self.sampleTransaction)] }
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
            $0.ledgerClient.listAll = { _ in [] }
            $0.ledgerClient.listCategories = { _ in [] }
            $0.ledgerClient.listAccounts = { [] }
            $0.ledgerClient.listTags = { [] }
        }
        await MainActor.run {
            store.exhaustivity = .off
        }

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
            $0.ledgerClient.listAll = { _ in [] }
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
            $0.ledgerClient.listAll = { _ in [EnrichedTransaction(transaction: Self.sampleTransaction)] }
        }
        await MainActor.run {
            store.exhaustivity = .off
        }

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
            $0.ledgerClient.delete = { _ in }
            $0.ledgerClient.listAll = { _ in [EnrichedTransaction(transaction: Self.sampleTransaction)] }
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
            $0.ledgerClient.listAll = { _ in [] }
            $0.ledgerClient.listCategories = { _ in [] }
            $0.ledgerClient.listAccounts = { [] }
            $0.ledgerClient.listTags = { [] }
        }
        await MainActor.run {
            store.exhaustivity = .off
        }

        await store.send(.transactionTapped(Self.sampleTransaction)) {
            $0.detail = TransactionDetailFeature.State(transaction: Self.sampleTransaction)
        }
    }

    // MARK: - activeFilter preservation (audit A1)

    @Test("addTransaction saved reload queries with activeFilter, not an empty filter")
    func testSavedReloadUsesActiveFilter() async {
        let captured = LockIsolated<TransactionFilter?>(nil)
        let activeFilter = TransactionFilter(types: [.expense])

        var initialState = TransactionsFeature.State()
        initialState.activeFilter = activeFilter
        initialState.addTransaction = AddTransactionFeature.State(mode: .add(.expense))

        let store = await TestStore(initialState: initialState) {
            TransactionsFeature()
        } withDependencies: {
            $0.ledgerClient.listAll = { filter in
                captured.setValue(filter)
                return []
            }
        }

        await store.send(.addTransaction(.presented(.delegate(.saved)))) {
            $0.addTransaction = nil
        }
        await store.receive(\.transactionsLoaded)
        #expect(captured.value == activeFilter)
    }

    @Test("clearing search restores the activeFilter-scoped list, not the full list")
    func testClearSearchUsesActiveFilter() async {
        let captured = LockIsolated<TransactionFilter?>(nil)
        let activeFilter = TransactionFilter(types: [.expense])

        var initialState = TransactionsFeature.State()
        initialState.activeFilter = activeFilter
        initialState.searchText = "abc"

        let store = await TestStore(initialState: initialState) {
            TransactionsFeature()
        } withDependencies: {
            $0.ledgerClient.listAll = { filter in
                captured.setValue(filter)
                return []
            }
        }

        await store.send(.searchTextChanged("")) {
            $0.searchText = ""
        }
        await store.receive(\.transactionsLoaded)
        #expect(captured.value == activeFilter)
    }

    // MARK: - B3 補強：addTransaction delegate dismissed

    @Test("addTransaction.delegate.dismissed closes the addTransaction sheet")
    func testAddTransactionDelegateDismissedClosesSheet() async {
        var initial = TransactionsFeature.State()
        initial.addTransaction = AddTransactionFeature.State(mode: .add(.expense))

        let store = await TestStore(initialState: initial) {
            TransactionsFeature()
        }

        await store.send(.addTransaction(.presented(.delegate(.dismissed)))) {
            $0.addTransaction = nil
        }
    }

    // 注意：Filter.Delegate.dismissed 在 A 波重構中已從 FilterFeature 刪除（FilterFeature 現在
    // 只有 .filterApplied），TransactionsFeature 不再有 .filter(.presented(.delegate(.dismissed)))
    // handler。此項跳過，符合 B3 任務說明「Filter 的 dismissed 已在 A3 刪除」的指示。

    // MARK: - Context Action

    @Test("contextActionTapped presents addTransaction sheet in .add(.expense) mode")
    @MainActor
    func testContextActionTappedPresentsAddTransaction() async {
        let store = TestStore(initialState: TransactionsFeature.State()) {
            TransactionsFeature()
        }
        await MainActor.run {
            store.exhaustivity = .off
        }

        // TransactionsFeature uses Date() directly (no date dependency), so we only verify
        // that the sheet is presented with the correct mode.
        await store.send(.contextActionTapped)
        #expect(store.state.addTransaction?.mode == .add(.expense))
        #expect(store.state.addTransaction?.type == .expense)
    }

    // MARK: - Effect error handling（health-audit A6 / A7）

    private struct StubError: LocalizedError, Equatable { var errorDescription: String? { "boom" } }

    @Test(".task failure sets loadError and clears isLoading")
    func testTaskFailureSetsLoadError() async {
        let store = await TestStore(initialState: TransactionsFeature.State()) {
            TransactionsFeature()
        } withDependencies: {
            $0.ledgerClient.listAll = { _ in throw StubError() }
        }
        await store.send(.task) { $0.isLoading = true }
        await store.receive(\.loadFailed) {
            $0.isLoading = false
            $0.loadError = "boom"
        }
    }

    @Test("searchDebounced queries listAll with activeFilter + searchText (filters are not dropped)")
    func testSearchRespectsActiveFilter() async {
        let categoryId = UUID()
        var initial = TransactionsFeature.State()
        initial.activeFilter = TransactionFilter(categoryIds: [categoryId])
        initial.searchText = "sushi"
        let captured = LockIsolated<TransactionFilter?>(nil)
        let store = await TestStore(initialState: initial) {
            TransactionsFeature()
        } withDependencies: {
            $0.ledgerClient.listAll = { filter in
                captured.setValue(filter)
                return []
            }
        }
        await store.send(.searchDebounced)
        // .searchDebounced 不切換 isLoading（沿用既有行為），且結果為空陣列本就等於初始值，
        // 故 receive 對 state 沒有可觀察變化 —— 依 TCA TestStore 的建議省略 trailing closure。
        await store.receive(\.transactionsLoaded)
        #expect(captured.value?.categoryIds == Set([categoryId]))
        #expect(captured.value?.searchText == "sushi")
    }

    @Test("deleteConfirmed failure surfaces loadError and keeps the row")
    func testDeleteFailureKeepsRow() async {
        var initial = TransactionsFeature.State()
        initial.transactions = [Self.sampleTransaction]
        initial.deleteConfirmationId = Self.sampleTransaction.id
        let store = await TestStore(initialState: initial) {
            TransactionsFeature()
        } withDependencies: {
            $0.ledgerClient.delete = { _ in throw StubError() }
        }
        await store.send(.deleteConfirmed) { $0.deleteConfirmationId = nil }
        await store.receive(\.loadFailed) { $0.loadError = "boom" }
        await MainActor.run { #expect(store.state.transactions.count == 1) }
    }

    @Test("loadFailed clears when a later load succeeds")
    func testLoadErrorClearsOnSuccess() async {
        var initial = TransactionsFeature.State()
        initial.loadError = "stale"
        let store = await TestStore(initialState: initial) {
            TransactionsFeature()
        } withDependencies: {
            $0.ledgerClient.listAll = { _ in [EnrichedTransaction(transaction: Self.sampleTransaction)] }
        }
        // .task 一送出就同步清空 loadError（不等 effect 完成），所以 send 的 closure 也要反映這個變化。
        await store.send(.task) {
            $0.isLoading = true
            $0.loadError = nil
        }
        await store.receive(\.transactionsLoaded) {
            $0.isLoading = false
            $0.transactions = [Self.sampleTransaction]
        }
    }
}

// MARK: - Task 1: searchDebounced → ledger.listAll(effectiveFilter) path（health-audit A7）
//
// 原本這個 suite 斷言 .searchDebounced 呼叫 ledger.search；stability-effect-errors Task 1
// Step 4／global-constraints R4 把這條路徑改成 listAll(effectiveFilter)（search 不再丟掉
// activeFilter）。ledger.search 這支 API 本身保留（R4），只是 TransactionsFeature 不再呼叫它，
// 因此把這兩個測試改成 stub listAll 並斷言傳入的 filter，語意與涵蓋範圍不變，斷言強度不放寬。

@Suite("TransactionsFeature — search debounced path")
struct TransactionsSearchDebouncedTests {

    static let coffeeTransaction = Transaction(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000099")!,
        amount: 60, date: Date(timeIntervalSince1970: 2_000_000),
        note: "咖啡拿鐵", accountId: UUID().uuidString, type: .expense
    )

    // 說明：TransactionsFeature 的 debounce 使用 RunLoop.main（不可控 scheduler），
    // 無法用 TestClock 推進。這裡直接 send(.searchDebounced) 測試 reload effect 本身，
    // 確保 ledger.listAll 帶著 effectiveFilter（含 searchText）被正確呼叫，且結果寫入 transactionsLoaded。
    @Test("searchDebounced calls ledger.listAll with effectiveFilter and loads results into state")
    func testSearchDebouncedCallsListAllAndLoadsResults() async {
        let capturedFilter = LockIsolated<TransactionFilter?>(nil)
        let searchCalled = LockIsolated(false)

        var initial = TransactionsFeature.State()
        initial.searchText = "咖啡"

        let store = await TestStore(initialState: initial) {
            TransactionsFeature()
        } withDependencies: {
            $0.ledgerClient.listAll = { filter in
                capturedFilter.setValue(filter)
                return [EnrichedTransaction(transaction: Self.coffeeTransaction)]
            }
            // regression（team-lead 裁定）：ledger.search API 雖保留（R4），但這個 feature
            // 不該再偷偷呼叫它 —— 用 spy 釘住「search 沒被呼叫」。
            $0.ledgerClient.search = { _ in
                searchCalled.setValue(true)
                return []
            }
        }

        await store.send(.searchDebounced)
        await store.receive(\.transactionsLoaded) {
            $0.transactions = [Self.coffeeTransaction]
        }

        // spy 確認搜尋字串是透過 effectiveFilter.searchText 正確傳遞
        #expect(capturedFilter.value?.searchText == "咖啡")
        #expect(searchCalled.value == false)
    }

    @Test("searchDebounced with no matching results clears transactions to empty")
    func testSearchDebouncedEmptyQuery() async {
        // 初始有一筆交易，搜尋後應回傳空陣列，驗證 state.transactions 被清空
        let nonMatchTx = Transaction(
            id: UUID(uuidString: "00000000-0000-0000-0000-00000000FFFF")!,
            amount: 100, date: Date(timeIntervalSince1970: 1_000_000),
            note: "晚餐", accountId: UUID().uuidString, type: .expense
        )
        var initial = TransactionsFeature.State()
        initial.transactions = [nonMatchTx]
        initial.searchText = "無結果"

        let capturedFilter = LockIsolated<TransactionFilter?>(nil)
        let store = await TestStore(initialState: initial) {
            TransactionsFeature()
        } withDependencies: {
            $0.ledgerClient.listAll = { filter in
                capturedFilter.setValue(filter)
                return []   // 無符合結果
            }
        }

        await store.send(.searchDebounced)
        await store.receive(\.transactionsLoaded) {
            $0.transactions = []   // state 改變：從有資料 → 空
            $0.isLoading = false
        }
        #expect(capturedFilter.value?.searchText == "無結果")
    }
}

// MARK: - Task 7: detail delegate 三分支

@Suite("TransactionsFeature — detail delegate branches")
struct TransactionsDetailDelegateTests {

    static let tx1 = Transaction(
        id: UUID(uuidString: "AAAAAAAA-0000-0000-0000-000000000001")!,
        amount: 100, date: Date(timeIntervalSince1970: 1_000_000),
        note: "晚餐", accountId: UUID().uuidString, type: .expense
    )
    static let tx2 = Transaction(
        id: UUID(uuidString: "AAAAAAAA-0000-0000-0000-000000000002")!,
        amount: 200, date: Date(timeIntervalSince1970: 1_100_000),
        note: "午餐", accountId: UUID().uuidString, type: .expense
    )

    // 分支 1：deleted — 從 state.transactions 移除並關閉 detail
    @Test("detail.delegate.deleted removes the transaction from state and closes detail")
    func testDetailDelegateDeletedRemovesRow() async {
        var initial = TransactionsFeature.State()
        initial.transactions = [Self.tx1, Self.tx2]
        initial.detail = TransactionDetailFeature.State(transaction: Self.tx1)

        let store = await TestStore(initialState: initial) {
            TransactionsFeature()
        }

        await store.send(.detail(.presented(.delegate(.deleted(Self.tx1.id))))) {
            $0.transactions = [Self.tx2]
            $0.detail = nil
        }
    }

    // 分支 2：updated — 替換該列（命中 firstIndex）並關閉 detail
    @Test("detail.delegate.updated replaces the row in state and closes detail")
    func testDetailDelegateUpdatedReplacesRow() async {
        // 建立更新後的版本（相同 id，不同 amount/note）
        let updatedTx1 = Transaction(
            id: Self.tx1.id,
            amount: 999, date: Self.tx1.date,
            note: "已修改晚餐", categoryId: nil,
            accountId: Self.tx1.accountId,
            toAccountId: nil, type: .expense
        )

        var initial = TransactionsFeature.State()
        initial.transactions = [Self.tx1, Self.tx2]
        initial.detail = TransactionDetailFeature.State(transaction: Self.tx1)

        let store = await TestStore(initialState: initial) {
            TransactionsFeature()
        }

        await store.send(.detail(.presented(.delegate(.updated(updatedTx1))))) {
            $0.transactions = [updatedTx1, Self.tx2]
            $0.detail = nil
        }
    }

    // 分支 3：dismiss — 清 detail 為 nil（手動 dismiss，非系統 .onDismiss）
    @Test("detail.dismiss clears detail state")
    func testDetailDismissClearsDetail() async {
        var initial = TransactionsFeature.State()
        initial.transactions = [Self.tx1]
        initial.detail = TransactionDetailFeature.State(transaction: Self.tx1)

        let store = await TestStore(initialState: initial) {
            TransactionsFeature()
        }

        await store.send(.detail(.dismiss)) {
            $0.detail = nil
        }
    }

    // updated 負例：id 不在清單中 → transactions 不變、detail 仍關閉
    @Test("detail.delegate.updated with unknown id leaves transactions unchanged but closes detail")
    func testDetailDelegateUpdatedUnknownIdNoChange() async {
        let unknownTx = Transaction(
            id: UUID(),   // 不在 state.transactions 中
            amount: 500, date: Date(),
            note: "不存在", accountId: UUID().uuidString, type: .expense
        )

        var initial = TransactionsFeature.State()
        initial.transactions = [Self.tx1, Self.tx2]
        initial.detail = TransactionDetailFeature.State(transaction: Self.tx1)

        let store = await TestStore(initialState: initial) {
            TransactionsFeature()
        }

        await store.send(.detail(.presented(.delegate(.updated(unknownTx))))) {
            // transactions 不變（firstIndex 命中失敗）
            $0.detail = nil
        }
    }
}
