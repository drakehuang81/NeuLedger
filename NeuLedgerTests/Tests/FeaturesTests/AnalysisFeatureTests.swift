import Testing
import Foundation
import ComposableArchitecture
import Domain
@testable import Features

@Suite("AnalysisFeature Tests")
struct AnalysisFeatureTests {

    // MARK: - Shared Helpers

    private static let categoryId = UUID()
    private static let accountId = UUID().uuidString

    private static let sampleCategory = Category(
        id: categoryId,
        name: "飲食",
        icon: "fork.knife",
        color: "red",
        type: .expense
    )

    /// Fixed anchor date for deterministic tests (start of a specific day).
    private static let day1: Date = {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 1; comps.day = 15
        return Calendar.current.date(from: comps)!
    }()

    private static let sampleTransactions: [Transaction] = [
        Transaction(amount: 300, date: day1, note: "午餐", categoryId: categoryId, accountId: accountId, type: .expense),
        Transaction(amount: 200, date: day1, note: "咖啡", categoryId: categoryId, accountId: accountId, type: .expense),
        Transaction(amount: 5000, date: day1, note: "薪資", accountId: accountId, type: .income),
        Transaction(amount: 1000, date: day1, note: "轉帳", accountId: accountId, toAccountId: UUID().uuidString, type: .transfer),
    ]

    // MARK: - Period Changed

    @Test("periodChanged updates selectedPeriod and triggers data reload")
    func testPeriodChanged() async {
        let store = await TestStore(initialState: AnalysisFeature.State()) {
            AnalysisFeature()
        } withDependencies: {
            $0.ledgerClient.listAll = { _ in [] }
            $0.planningClient.listActive = { [] }
            $0.ledgerClient.listCategories = { _ in [] }
            $0.insightsClient.isAIAvailable = { false }
        }
        await MainActor.run {
            store.exhaustivity = .off
        }

        await store.send(.periodChanged(.week)) { $0.selectedPeriod = .week }
        // loadData and its downstream effects are fired — exhaustivity.off skips them
    }

    // MARK: - loadData: Happy Path

    @Test("loadData computes correct summary, proportions, and trends; excludes transfers")
    func testLoadDataHappyPath() async {
        let store = await TestStore(initialState: AnalysisFeature.State()) {
            AnalysisFeature()
        } withDependencies: {
            $0.ledgerClient.listAll = { _ in Self.sampleTransactions.map { EnrichedTransaction(transaction: $0) } }
            $0.planningClient.listActive = { [] }
            $0.ledgerClient.listCategories = { _ in [Self.sampleCategory] }
            $0.insightsClient.isAIAvailable = { false }
        }
        await MainActor.run {
            store.exhaustivity = .off
        }

        await store.send(.loadData) { $0.isLoading = true }

        await store.receive(\.loadedData) {
            $0.isLoading = false
            $0.summary = FinancialSummary(totalIncome: 5000, totalExpense: 500)
            $0.categoryProportions = [
                CategoryProportion(id: Self.categoryId.uuidString, name: "飲食", amount: 500)
            ]
            $0.dailyTrends = [DailyTrend(date: Self.day1, amount: 500)]
            $0.insight = nil
        }
    }

    // MARK: - loadData: Empty Transactions

    @Test("loadData with empty transactions clears state and sets hasData to false")
    func testLoadDataEmptyTransactions() async {
        var initialState = AnalysisFeature.State()
        initialState.summary = FinancialSummary(totalIncome: 100, totalExpense: 50)

        let store = await TestStore(initialState: initialState) {
            AnalysisFeature()
        } withDependencies: {
            $0.ledgerClient.listAll = { _ in [] }
            $0.planningClient.listActive = { [] }
            $0.ledgerClient.listCategories = { _ in [] }
            $0.insightsClient.isAIAvailable = { false }
        }
        await MainActor.run {
            store.exhaustivity = .off
        }

        await store.send(.loadData) { $0.isLoading = true }

        await store.receive(\.loadedData) {
            $0.isLoading = false
            $0.summary = nil
            $0.categoryProportions = []
            $0.dailyTrends = []
            $0.insight = nil
        }
    }

    // MARK: - loadData: Failure

    @Test("loadedData failure sets isLoading to false and leaves other state unchanged")
    func testLoadedDataFailure() async {
        let store = await TestStore(initialState: AnalysisFeature.State()) {
            AnalysisFeature()
        } withDependencies: {
            $0.ledgerClient.listAll = { _ in throw URLError(.badServerResponse) }
            $0.planningClient.listActive = { [] }
            $0.ledgerClient.listCategories = { _ in [] }
            $0.insightsClient.isAIAvailable = { false }
        }
        await MainActor.run {
            store.exhaustivity = .off
        }

        await store.send(.loadData) { $0.isLoading = true }
        await store.receive(\.loadedData) { $0.isLoading = false }
    }

    // MARK: - AI Insight

    @Test("loadData generates AI insight when available")
    func testLoadDataAIInsightAvailable() async {
        let insightText = "本月消費偏高，建議減少外食。"

        let store = await TestStore(initialState: AnalysisFeature.State()) {
            AnalysisFeature()
        } withDependencies: {
            $0.ledgerClient.listAll = { _ in Self.sampleTransactions.map { EnrichedTransaction(transaction: $0) } }
            $0.planningClient.listActive = { [] }
            $0.ledgerClient.listCategories = { _ in [Self.sampleCategory] }
            $0.insightsClient.isAIAvailable = { true }
            $0.insightsClient.generateAIInsight = { _ in insightText }
        }
        await MainActor.run {
            store.exhaustivity = .off
        }

        await store.send(.loadData) { $0.isLoading = true }
        await store.receive(\.loadedData) {
            $0.isLoading = false
            $0.insight = InsightDetail(
                id: $0.insight?.id ?? "",
                title: String(localized: "analysis_ai_insight_title"),
                description: insightText
            )
        }
    }

    @Test("loadData sets insight to nil when generateInsight throws")
    func testLoadDataAIInsightFailsGracefully() async {
        struct AIError: Error {}

        let store = await TestStore(initialState: AnalysisFeature.State()) {
            AnalysisFeature()
        } withDependencies: {
            $0.ledgerClient.listAll = { _ in Self.sampleTransactions.map { EnrichedTransaction(transaction: $0) } }
            $0.planningClient.listActive = { [] }
            $0.ledgerClient.listCategories = { _ in [Self.sampleCategory] }
            $0.insightsClient.isAIAvailable = { true }
            $0.insightsClient.generateAIInsight = { _ in throw AIError() }
        }
        await MainActor.run {
            store.exhaustivity = .off
        }

        await store.send(.loadData) { $0.isLoading = true }
        await store.receive(\.loadedData) {
            $0.isLoading = false
            $0.insight = nil
            // Other data is still populated
            $0.summary = FinancialSummary(totalIncome: 5000, totalExpense: 500)
        }
    }

    // MARK: - Budget Metrics

    @Test("budgetMetricsLoaded updates budgetMetrics state")
    func testBudgetMetricsLoaded() async {
        let metrics = [
            BudgetGaugeMetrics(id: "b1", categoryName: "飲食", spentAmount: 400, totalBudget: 1000)
        ]

        let store = await TestStore(initialState: AnalysisFeature.State()) {
            AnalysisFeature()
        }

        await store.send(.budgetMetricsLoaded(metrics)) { $0.budgetMetrics = metrics }
    }

    @Test("loadData computes budget metrics with categoryName resolved from category map")
    func testLoadDataBudgetMetrics() async {
        let budget = Budget(
            name: "餐費預算",
            amount: 1000,
            categoryId: Self.categoryId,
            period: .monthly,
            startDate: Date()
        )
        let budgetTxns = [
            Transaction(amount: 400, date: Date(), categoryId: Self.categoryId, accountId: Self.accountId, type: .expense)
        ]

        let store = await TestStore(initialState: AnalysisFeature.State()) {
            AnalysisFeature()
        } withDependencies: {
            $0.ledgerClient.listAll = { _ in budgetTxns.map { EnrichedTransaction(transaction: $0) } }
            $0.planningClient.listActive = { [budget] }
            $0.ledgerClient.listCategories = { _ in [Self.sampleCategory] }
            $0.insightsClient.isAIAvailable = { false }
        }
        await MainActor.run {
            store.exhaustivity = .off
        }

        await store.send(.loadData)
        await store.receive(\.budgetMetricsLoaded) {
            $0.budgetMetrics = [
                BudgetGaugeMetrics(
                    id: budget.id.uuidString,
                    categoryName: "飲食",   // resolved from categoryMap, not budget.name
                    spentAmount: 400,
                    totalBudget: 1000
                )
            ]
        }
    }

    // MARK: - Category Drill-down

    @Test("categoryTapped fetches filtered transactions and sets drilldown state")
    func testCategoryTapped() async {
        let categoryId = UUID()
        let proportion = CategoryProportion(id: categoryId.uuidString, name: "飲食", amount: 500)
        let expectedTransactions: [Transaction] = [
            Transaction(amount: 300, date: Date(), note: "午餐", categoryId: categoryId, accountId: UUID().uuidString, type: .expense),
            Transaction(amount: 200, date: Date(), note: "晚餐", categoryId: categoryId, accountId: UUID().uuidString, type: .expense),
        ]

        var initialState = AnalysisFeature.State()
        initialState.summary = FinancialSummary(totalIncome: 0, totalExpense: 500)
        initialState.categoryProportions = [proportion]

        let store = await TestStore(initialState: initialState) {
            AnalysisFeature()
        } withDependencies: {
            $0.ledgerClient.listAll = { _ in expectedTransactions.map { EnrichedTransaction(transaction: $0) } }
        }

        await store.send(.categoryTapped(proportion))
        await store.receive(\.categoryTransactionsLoaded) {
            $0.categoryDrilldown = AnalysisFeature.CategoryDrilldownState(
                categoryName: "飲食",
                transactions: expectedTransactions
            )
        }
    }

    @Test("categoryTapped with uncategorized id uses nil categoryIds in filter")
    func testCategoryTappedUncategorized() async {
        let proportion = CategoryProportion(id: "uncategorized", name: "其他", amount: 150)

        let capturedFilter = LockIsolated<TransactionFilter?>(nil)
        let store = await TestStore(initialState: AnalysisFeature.State()) {
            AnalysisFeature()
        } withDependencies: {
            $0.ledgerClient.listAll = { filter in
                capturedFilter.setValue(filter)
                return []
            }
        }
        await MainActor.run {
            store.exhaustivity = .off
        }

        await store.send(.categoryTapped(proportion))
        await store.receive(\.categoryTransactionsLoaded)

        #expect(capturedFilter.value?.categoryIds == nil)
    }

    @Test("categoryTapped fetch failure results in empty transactions drilldown")
    func testCategoryTappedFetchFailure() async {
        struct FetchError: Error {}
        let proportion = CategoryProportion(id: UUID().uuidString, name: "飲食", amount: 300)

        let store = await TestStore(initialState: AnalysisFeature.State()) {
            AnalysisFeature()
        } withDependencies: {
            $0.ledgerClient.listAll = { _ in throw FetchError() }
        }

        await store.send(.categoryTapped(proportion))
        await store.receive(\.categoryTransactionsLoaded) {
            $0.categoryDrilldown = AnalysisFeature.CategoryDrilldownState(
                categoryName: "飲食",
                transactions: []
            )
        }
    }

    @Test("categoryDrilldownDismissed clears drilldown state")
    func testCategoryDrilldownDismissed() async {
        var initialState = AnalysisFeature.State()
        initialState.categoryDrilldown = AnalysisFeature.CategoryDrilldownState(
            categoryName: "飲食",
            transactions: []
        )

        let store = await TestStore(initialState: initialState) {
            AnalysisFeature()
        }

        await store.send(.categoryDrilldownDismissed) { $0.categoryDrilldown = nil }
    }

    // MARK: - Edge Cases

    @Test("loadData groups uncategorized transactions under uncategorized proportion")
    func testLoadDataUncategorizedTransactions() async {
        let txns = [
            Transaction(amount: 150, date: Self.day1, accountId: Self.accountId, type: .expense)
            // categoryId is nil → "uncategorized"
        ]

        let store = await TestStore(initialState: AnalysisFeature.State()) {
            AnalysisFeature()
        } withDependencies: {
            $0.ledgerClient.listAll = { _ in txns.map { EnrichedTransaction(transaction: $0) } }
            $0.planningClient.listActive = { [] }
            $0.ledgerClient.listCategories = { _ in [] }
            $0.insightsClient.isAIAvailable = { false }
        }
        await MainActor.run {
            store.exhaustivity = .off
        }

        await store.send(.loadData)
        await store.receive(\.loadedData) {
            let proportion = $0.categoryProportions.first
            #expect(proportion?.id == "uncategorized")
            #expect(proportion?.amount == 150)
        }
    }

    @Test("computeBudgetMetrics falls back to budget name when budget has no categoryId")
    func testBudgetMetricsNoCategoryId() async {
        let budget = Budget(
            name: "總支出預算",
            amount: 5000,
            categoryId: nil,   // global budget
            period: .monthly,
            startDate: Date()
        )

        let store = await TestStore(initialState: AnalysisFeature.State()) {
            AnalysisFeature()
        } withDependencies: {
            $0.ledgerClient.listAll = { _ in [] }
            $0.planningClient.listActive = { [budget] }
            $0.ledgerClient.listCategories = { _ in [] }
            $0.insightsClient.isAIAvailable = { false }
        }
        await MainActor.run {
            store.exhaustivity = .off
        }

        await store.send(.loadData)
        await store.receive(\.budgetMetricsLoaded) {
            #expect($0.budgetMetrics.first?.categoryName == "總支出預算")
        }
    }

    // MARK: - Account Filter

    @Test("task loads active accounts into state")
    func testTaskLoadsAccounts() async {
        let accounts = [
            Account(name: "現金", type: .cash, icon: "banknote", color: "#34C759", sortOrder: 0),
            Account(name: "銀行", type: .bank, icon: "building.columns", color: "#3478F6", sortOrder: 1),
        ]
        let store = await TestStore(initialState: AnalysisFeature.State()) {
            AnalysisFeature()
        } withDependencies: {
            $0.ledgerClient.listActiveAccounts = { accounts }
            $0.ledgerClient.listAll = { _ in [] }
            $0.planningClient.listActive = { [] }
            $0.ledgerClient.listCategories = { _ in [] }
            $0.insightsClient.isAIAvailable = { false }
        }
        await MainActor.run {
            store.exhaustivity = .off
        }

        await store.send(.task)
        await store.receive(\.accountsLoaded) { $0.accounts = accounts }
    }

    // MARK: - AI Assistant availability

    @Test("task forwards aiAssistant.task so the availability gate can resolve")
    func testTaskForwardsAIAssistantTask() async {
        let store = await TestStore(initialState: AnalysisFeature.State()) {
            AnalysisFeature()
        } withDependencies: {
            $0.ledgerClient.listActiveAccounts = { [] }
            $0.ledgerClient.listAll = { _ in [] }
            $0.ledgerClient.listCategories = { _ in [] }
            $0.planningClient.listActive = { [] }
            $0.insightsClient.isAIAvailable = { true }
        }
        await MainActor.run {
            store.exhaustivity = .off
        }

        await store.send(.task)
        // 修復前：.task 只 merge accounts 載入與 .loadData，永遠等不到這個 receive
        await store.receive(\.aiAssistant.task) {
            $0.aiAssistant.isAvailable = true
        }
    }

    @Test("accountSelected updates selectedAccountId and triggers loadData")
    func testAccountSelected() async {
        let accountId = UUID().uuidString
        let store = await TestStore(initialState: AnalysisFeature.State()) {
            AnalysisFeature()
        } withDependencies: {
            $0.ledgerClient.listAll = { _ in [] }
            $0.planningClient.listActive = { [] }
            $0.ledgerClient.listCategories = { _ in [] }
            $0.insightsClient.isAIAvailable = { false }
        }
        await MainActor.run {
            store.exhaustivity = .off
        }

        await store.send(.accountSelected(accountId)) {
            $0.selectedAccountId = accountId
        }
        // loadData is triggered — exhaustivity.off skips downstream
    }

    @Test("loadData passes accountIds filter when selectedAccountId is set")
    func testLoadDataPassesAccountFilter() async {
        let accountId = UUID().uuidString
        var initial = AnalysisFeature.State()
        initial.selectedAccountId = accountId

        let capturedFilter = LockIsolated<TransactionFilter?>(nil)
        let store = await TestStore(initialState: initial) {
            AnalysisFeature()
        } withDependencies: {
            $0.ledgerClient.listAll = { filter in
                capturedFilter.setValue(filter)
                return []
            }
            $0.planningClient.listActive = { [] }
            $0.ledgerClient.listCategories = { _ in [] }
            $0.insightsClient.isAIAvailable = { false }
        }
        await MainActor.run {
            store.exhaustivity = .off
        }

        await store.send(.loadData)
        await store.receive(\.loadedData)

        #expect(capturedFilter.value?.accountIds == Set([accountId]))
    }

    // MARK: - B3 補強：loadData 兩條並發 effect 協調

    // MARK: - B3 補強：loadData 兩條並發 effect 協調（驗證兩條都到齊）
    //
    // loadData 用 .merge() 同時發起兩條 effect：
    //   ① 主資料 effect → .loadedData(.success(data))
    //   ② budget effect → .budgetMetricsLoaded(metrics)
    // 兩條到達順序不確定，用各自獨立的 receive 驗證 + exhaustivity = .off 處理任意順序。
    @Test("loadData sends both loadedData and budgetMetricsLoaded — both effects arrive")
    func testLoadDataBothEffectsArrive() async {
        let budget = Budget(
            name: "餐費預算", amount: 1000,
            categoryId: Self.categoryId, period: .monthly, startDate: Date()
        )
        let txn = Transaction(
            amount: 300, date: Self.day1, note: "午餐",
            categoryId: Self.categoryId, accountId: Self.accountId, type: .expense
        )

        let store = await TestStore(initialState: AnalysisFeature.State()) {
            AnalysisFeature()
        } withDependencies: {
            $0.ledgerClient.listAll = { _ in [EnrichedTransaction(transaction: txn)] }
            $0.planningClient.listActive = { [budget] }
            $0.ledgerClient.listCategories = { _ in [Self.sampleCategory] }
            $0.insightsClient.isAIAvailable = { false }
        }
        // 兩條並發 effect 到達順序不確定 → exhaustivity = .off
        await MainActor.run { store.exhaustivity = .off }

        await store.send(.loadData)

        // 各自 receive 兩條，順序無要求（exhaustivity = .off）
        await store.receive(\.loadedData)
        await store.receive(\.budgetMetricsLoaded)

        // 等待所有 effect 靜默結束
        await store.finish()

        // 最終 state 驗證：兩條 effect 都寫入正確值
        await MainActor.run {
            #expect(store.state.isLoading == false)
            #expect(store.state.summary == FinancialSummary(totalIncome: 0, totalExpense: 300))
            #expect(store.state.budgetMetrics.count == 1)
            #expect(store.state.budgetMetrics.first?.id == budget.id.uuidString)
        }
    }

    // MARK: - B3 補強：loadData cancelInFlight 取消前一個 budget effect
    //
    // AnalysisFeature.loadData 的 budget effect 帶 .cancellable(id: CancelID.budgets, cancelInFlight: true)。
    // 此測試驗證：連續兩次 loadData 後，最終 state 中的 budgetMetrics 是「第二次」的結果。
    //
    // 鑑別力設計：用 LockIsolated 計數器讓 listActive 每次回傳「不同 id」的 budget。
    //   - 第一次 loadData → planningClient.listActive 回傳 firstBudget
    //   - 第二次 loadData → 回傳 secondBudget（不同 id）
    // 若 cancelInFlight 正確運作，最終 budgetMetrics 只會是 secondBudget；
    // 若 cancelInFlight 失效（兩條 budget effect 都跑完且後者先回），斷言會抓到 firstBudget 殘留。
    //
    // 注意：使用 exhaustivity = .off 是必要的，因為兩條 .merge effect 順序不確定，
    // 且第一次 budget effect 被取消時 TestStore 不會收到其對應 action。
    @Test("consecutive loadData: cancelInFlight ensures final budgetMetrics is the second invocation's result")
    func testLoadDataCancelInFlightBudgetEffect() async {
        let firstBudget = Budget(
            name: "第一次預算", amount: 1000,
            categoryId: Self.categoryId, period: .monthly, startDate: Date()
        )
        let secondBudget = Budget(
            name: "第二次預算", amount: 2000,
            categoryId: Self.categoryId, period: .monthly, startDate: Date()
        )
        // 計數器：第一次呼叫回傳 firstBudget，第二次（含之後）回傳 secondBudget
        let listActiveCallCount = LockIsolated(0)

        let store = await TestStore(initialState: AnalysisFeature.State()) {
            AnalysisFeature()
        } withDependencies: {
            $0.ledgerClient.listAll = { _ in [] }
            $0.planningClient.listActive = {
                let n = listActiveCallCount.withValue { count -> Int in
                    count += 1
                    return count
                }
                return n == 1 ? [firstBudget] : [secondBudget]
            }
            $0.ledgerClient.listCategories = { _ in [Self.sampleCategory] }
            $0.insightsClient.isAIAvailable = { false }
        }
        // exhaustivity = .off：不要求每個被取消/順序不確定的 action 都被 receive
        await MainActor.run { store.exhaustivity = .off }

        // 第一次 loadData — 啟動 budget effect（listActive → firstBudget）
        await store.send(.loadData)
        // 立即送第二次 loadData — cancelInFlight 應取消第一次 budget effect 並重新啟動（listActive → secondBudget）
        await store.send(.loadData)

        // 收到最後一次 loadData 的兩個下游 action（順序不確定）
        await store.receive(\.loadedData)
        await store.receive(\.budgetMetricsLoaded)

        await store.finish()

        // 鑑別斷言：最終 budgetMetrics 必須是「第二次」的 secondBudget，而非 firstBudget。
        // 這才真正驗證 cancelInFlight 把第一次的結果丟棄、只保留第二次。
        await MainActor.run {
            #expect(store.state.budgetMetrics.count == 1)
            #expect(store.state.budgetMetrics.first?.id == secondBudget.id.uuidString)
            #expect(store.state.budgetMetrics.first?.id != firstBudget.id.uuidString)
        }
    }

    @Test("computeBudgetMetrics filters budgets to account-relevant categories")
    func testBudgetMetricsAccountFilter() async {
        let accountId = UUID().uuidString
        let relevantCategoryId = UUID()
        let irrelevantCategoryId = UUID()

        let relevantBudget = Budget(
            name: "飲食預算", amount: 1000,
            categoryId: relevantCategoryId, period: .monthly, startDate: Date()
        )
        let irrelevantBudget = Budget(
            name: "交通預算", amount: 500,
            categoryId: irrelevantCategoryId, period: .monthly, startDate: Date()
        )
        let accountTxn = Transaction(
            amount: 200, date: Date(),
            categoryId: relevantCategoryId, accountId: accountId, type: .expense
        )

        var initial = AnalysisFeature.State()
        initial.selectedAccountId = accountId

        let store = await TestStore(initialState: initial) {
            AnalysisFeature()
        } withDependencies: {
            $0.ledgerClient.listAll = { _ in [accountTxn].map { EnrichedTransaction(transaction: $0) } }
            $0.planningClient.listActive = { [relevantBudget, irrelevantBudget] }
            $0.ledgerClient.listCategories = { _ in [] }
            $0.insightsClient.isAIAvailable = { false }
        }
        await MainActor.run {
            store.exhaustivity = .off
        }

        await store.send(.loadData)
        await store.receive(\.budgetMetricsLoaded) {
            #expect($0.budgetMetrics.count == 1)
            #expect($0.budgetMetrics.first?.id == relevantBudget.id.uuidString)
        }
    }
}
