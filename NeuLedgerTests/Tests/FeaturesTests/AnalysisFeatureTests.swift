import Testing
import Foundation
import ComposableArchitecture
import Domain
@testable import Features

@Suite("AnalysisFeature Tests")
struct AnalysisFeatureTests {

    // MARK: - Shared Helpers

    private static let categoryId = UUID()
    private static let accountId = UUID()

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
        Transaction(amount: 1000, date: day1, note: "轉帳", accountId: accountId, toAccountId: UUID(), type: .transfer),
    ]

    // MARK: - Dismiss Insight

    @Test("dismissInsight sets insight to nil")
    func testDismissInsight() async {
        var initialState = AnalysisFeature.State()
        initialState.insight = InsightDetail(id: "test-id", title: "AI 洞察", description: "本月飲食花費增加 15%")

        let store = await TestStore(initialState: initialState) {
            AnalysisFeature()
        }

        await store.send(.dismissInsight) { $0.insight = nil }
    }

    // MARK: - Period Changed

    @Test("periodChanged updates selectedPeriod and triggers data reload")
    func testPeriodChanged() async {
        let store = await TestStore(initialState: AnalysisFeature.State()) {
            AnalysisFeature()
        } withDependencies: {
            $0.transactionClient.fetch = { _ in [] }
            $0.budgetClient.fetchActive = { [] }
            $0.categoryClient.fetchAll = { [] }
            $0.aiUseCase.isAvailable = { false }
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
            $0.transactionClient.fetch = { _ in Self.sampleTransactions }
            $0.budgetClient.fetchActive = { [] }
            $0.categoryClient.fetchAll = { [Self.sampleCategory] }
            $0.aiUseCase.isAvailable = { false }
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
            $0.transactionClient.fetch = { _ in [] }
            $0.budgetClient.fetchActive = { [] }
            $0.categoryClient.fetchAll = { [] }
            $0.aiUseCase.isAvailable = { false }
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
            $0.transactionClient.fetch = { _ in throw URLError(.badServerResponse) }
            $0.budgetClient.fetchActive = { [] }
            $0.categoryClient.fetchAll = { [] }
            $0.aiUseCase.isAvailable = { false }
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
            $0.transactionClient.fetch = { _ in Self.sampleTransactions }
            $0.budgetClient.fetchActive = { [] }
            $0.categoryClient.fetchAll = { [Self.sampleCategory] }
            $0.aiUseCase.isAvailable = { true }
            $0.aiUseCase.generateInsight = { _ in insightText }
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
            $0.transactionClient.fetch = { _ in Self.sampleTransactions }
            $0.budgetClient.fetchActive = { [] }
            $0.categoryClient.fetchAll = { [Self.sampleCategory] }
            $0.aiUseCase.isAvailable = { true }
            $0.aiUseCase.generateInsight = { _ in throw AIError() }
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
            $0.transactionClient.fetch = { _ in budgetTxns }
            $0.budgetClient.fetchActive = { [budget] }
            $0.categoryClient.fetchAll = { [Self.sampleCategory] }
            $0.aiUseCase.isAvailable = { false }
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
            Transaction(amount: 300, date: Date(), note: "午餐", categoryId: categoryId, accountId: UUID(), type: .expense),
            Transaction(amount: 200, date: Date(), note: "晚餐", categoryId: categoryId, accountId: UUID(), type: .expense),
        ]

        var initialState = AnalysisFeature.State()
        initialState.summary = FinancialSummary(totalIncome: 0, totalExpense: 500)
        initialState.categoryProportions = [proportion]

        let store = await TestStore(initialState: initialState) {
            AnalysisFeature()
        } withDependencies: {
            $0.transactionClient.fetch = { _ in expectedTransactions }
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
            $0.transactionClient.fetch = { filter in
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
            $0.transactionClient.fetch = { _ in throw FetchError() }
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
            $0.transactionClient.fetch = { _ in txns }
            $0.budgetClient.fetchActive = { [] }
            $0.categoryClient.fetchAll = { [] }
            $0.aiUseCase.isAvailable = { false }
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
            $0.transactionClient.fetch = { _ in [] }
            $0.budgetClient.fetchActive = { [budget] }
            $0.categoryClient.fetchAll = { [] }
            $0.aiUseCase.isAvailable = { false }
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
            $0.accountClient.fetchActive = { accounts }
            $0.transactionClient.fetch = { _ in [] }
            $0.budgetClient.fetchActive = { [] }
            $0.categoryClient.fetchAll = { [] }
            $0.aiUseCase.isAvailable = { false }
        }
        await MainActor.run {
            store.exhaustivity = .off
        }

        await store.send(.task)
        await store.receive(\.accountsLoaded) { $0.accounts = accounts }
    }

    @Test("accountSelected updates selectedAccountId and triggers loadData")
    func testAccountSelected() async {
        let accountId = UUID()
        let store = await TestStore(initialState: AnalysisFeature.State()) {
            AnalysisFeature()
        } withDependencies: {
            $0.transactionClient.fetch = { _ in [] }
            $0.budgetClient.fetchActive = { [] }
            $0.categoryClient.fetchAll = { [] }
            $0.aiUseCase.isAvailable = { false }
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
        let accountId = UUID()
        var initial = AnalysisFeature.State()
        initial.selectedAccountId = accountId

        let capturedFilter = LockIsolated<TransactionFilter?>(nil)
        let store = await TestStore(initialState: initial) {
            AnalysisFeature()
        } withDependencies: {
            $0.transactionClient.fetch = { filter in
                capturedFilter.setValue(filter)
                return []
            }
            $0.budgetClient.fetchActive = { [] }
            $0.categoryClient.fetchAll = { [] }
            $0.aiUseCase.isAvailable = { false }
        }
        await MainActor.run {
            store.exhaustivity = .off
        }

        await store.send(.loadData)
        await store.receive(\.loadedData)

        #expect(capturedFilter.value?.accountIds == Set([accountId]))
    }

    @Test("computeBudgetMetrics filters budgets to account-relevant categories")
    func testBudgetMetricsAccountFilter() async {
        let accountId = UUID()
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
            $0.transactionClient.fetch = { _ in [accountTxn] }
            $0.budgetClient.fetchActive = { [relevantBudget, irrelevantBudget] }
            $0.categoryClient.fetchAll = { [] }
            $0.aiUseCase.isAvailable = { false }
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
