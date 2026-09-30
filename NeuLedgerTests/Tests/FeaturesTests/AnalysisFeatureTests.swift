import Testing
import Foundation
import ComposableArchitecture
import Domain
@testable import Features

/// Analysis 改為完全透過 `insightsClient` 取投影後的 reducer 測試。
/// 彙總正確性由 `InsightsClientLiveTests` 負責；這裡只驗 reducer 的協調與參數傳遞。
@Suite("AnalysisFeature Tests")
struct AnalysisFeatureTests {

    // MARK: - Shared Helpers

    private static let categoryId = UUID()
    private static let accountId = UUID().uuidString

    private static var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Taipei")!
        return cal
    }
    private static let now: Date = calendar.date(from: DateComponents(year: 2026, month: 1, day: 15, hour: 12))!

    private static let sampleSummary = FinancialSummary(totalIncome: 5000, totalExpense: 500)
    private static let sampleProportions = [
        CategoryProportion(id: categoryId.uuidString, name: "飲食", amount: 500)
    ]
    private static let sampleTrends = [DailyTrend(date: calendar.startOfDay(for: now), amount: 500)]

    /// C5：`.loadedData(.failure)` 寫進 state 的訊息。這裡刻意用**同一個 key** 算出期望值，
    /// 所以斷言測的是「有沒有把錯誤外顯」而不是文案內容——實作若退回成只清 `isLoading`
    /// （`loadError` 留在 nil），相關測試就會變紅。
    private static let loadFailureMessage = String(localized: "analysis_load_failed", bundle: .main)

    /// 所有 loadData 路徑會碰到的 closure 一次覆寫；個別測試再覆蓋需要的部分。
    ///
    /// `financialSummary` 一定要在這裡顯式 stub：它在 `InsightsClient` 有顯式預設值
    /// （`0/0`），`@DependencyClient` 不會為它產生 unimplemented，而 `KPIStrip` 對
    /// 「`totalIncome <= 0` → 儲蓄率不可得」有專門分支——忘了接線會長得像一個正常的空狀態，
    /// 不會有任何測試變紅。
    private static func baseDependencies(_ deps: inout DependencyValues) {
        deps.date = .constant(now)
        deps.calendar = calendar
        deps.insightsClient.financialSummary = { _, _ in sampleSummary }
        deps.insightsClient.categoryProportions = { _, _ in sampleProportions }
        deps.insightsClient.dailyBars = { _, _ in sampleTrends }
        deps.insightsClient.budgetGauges = { _ in [] }
        deps.insightsClient.isAIAvailable = { false }
    }

    private static func makeStore(
        _ initial: AnalysisFeature.State = AnalysisFeature.State(),
        _ configure: @escaping @Sendable (inout DependencyValues) -> Void = { _ in }
    ) async -> TestStoreOf<AnalysisFeature> {
        let store = await TestStore(initialState: initial) {
            AnalysisFeature()
        } withDependencies: {
            baseDependencies(&$0)
            configure(&$0)
        }
        await MainActor.run { store.exhaustivity = .off }
        return store
    }

    // MARK: - Period / account selection

    @Test("periodChanged updates selectedPeriod and reloads")
    func testPeriodChanged() async {
        let store = await Self.makeStore()
        await store.send(.periodChanged(.weekly)) { $0.selectedPeriod = .weekly }
        await store.receive(\.loadData) { $0.isLoading = true }
    }

    @Test("accountSelected updates selectedAccountId and reloads")
    func testAccountSelected() async {
        let store = await Self.makeStore()
        await store.send(.accountSelected(Self.accountId)) { $0.selectedAccountId = Self.accountId }
        await store.receive(\.loadData) { $0.isLoading = true }
    }

    @Test("loadData passes the full calendar interval of the selected period and the selected account to every projection")
    func testLoadDataPassesIntervalAndAccount() async {
        let captured = LockIsolated<[(DateInterval, Account.ID?)]>([])
        var initial = AnalysisFeature.State(selectedPeriod: .weekly)
        initial.selectedAccountId = Self.accountId
        let store = await Self.makeStore(initial) {
            $0.insightsClient.financialSummary = { r, a in captured.withValue { $0.append((r, a)) }; return Self.sampleSummary }
            $0.insightsClient.categoryProportions = { r, a in captured.withValue { $0.append((r, a)) }; return [] }
            $0.insightsClient.dailyBars = { r, a in captured.withValue { $0.append((r, a)) }; return [] }
        }
        await store.send(.loadData)
        await store.receive(\.loadedData)

        let expected = BudgetPeriod.weekly.dateInterval(containing: Self.now, calendar: Self.calendar)
        #expect(captured.value.count == 3)
        #expect(captured.value.allSatisfy { $0.0 == expected && $0.1 == Self.accountId })
    }

    // MARK: - loadData outcomes

    @Test("loadData stores summary, proportions, trends from insightsClient")
    func testLoadDataHappyPath() async {
        let store = await Self.makeStore()
        await store.send(.loadData) { $0.isLoading = true }
        await store.receive(\.loadedData) {
            $0.isLoading = false
            $0.loadError = nil
            $0.summary = Self.sampleSummary
            $0.categoryProportions = Self.sampleProportions
            $0.dailyTrends = Self.sampleTrends
            $0.insight = nil
        }
        // F7：KPI 的值必須是被接線過來的非零數字，不是安靜的 0/0 預設值。
        await MainActor.run {
            #expect(store.state.summary?.totalIncome == 5000)
            #expect(store.state.summary?.totalExpense == 500)
            #expect(store.state.hasData)
        }
    }

    @Test("loadData with zero income and zero expense clears state (empty period)")
    func testLoadDataEmptyPeriod() async {
        var initial = AnalysisFeature.State()
        initial.summary = Self.sampleSummary
        initial.categoryProportions = Self.sampleProportions
        let store = await Self.makeStore(initial) {
            $0.insightsClient.financialSummary = { _, _ in FinancialSummary(totalIncome: 0, totalExpense: 0) }
            $0.insightsClient.categoryProportions = { _, _ in [] }
            $0.insightsClient.dailyBars = { _, _ in [] }
        }
        await store.send(.loadData) { $0.isLoading = true }
        await store.receive(\.loadedData) {
            $0.isLoading = false
            $0.summary = nil
            $0.categoryProportions = []
            $0.dailyTrends = []
            $0.insight = nil
        }
        // 空期間不是錯誤——`loadError` 必須維持 nil，畫面才會落在空狀態而不是失敗狀態。
        await MainActor.run { #expect(store.state.loadError == nil) }
    }

    // MARK: - C5：載入失敗必須外顯

    @Test("loadedData failure surfaces a retryable error instead of a fake empty state")
    func testLoadedDataFailureSurfacesError() async {
        let store = await Self.makeStore() {
            $0.insightsClient.financialSummary = { _, _ in throw URLError(.badServerResponse) }
        }
        await store.send(.loadData) { $0.isLoading = true }
        await store.receive(\.loadedData) {
            $0.isLoading = false
            // 修復前：這裡只有 `isLoading = false`，`loadError` 永遠是 nil，
            // 畫面於是落到 `!hasData` 的空狀態，對使用者說「你沒有任何資料」。
            $0.loadError = Self.loadFailureMessage
        }
        await MainActor.run {
            #expect(store.state.loadError != nil)
            #expect(store.state.hasData == false)
        }
    }

    @Test("loadData clears a stale loadError before refetching")
    func testLoadDataClearsPreviousError() async {
        var initial = AnalysisFeature.State()
        initial.loadError = "上一次失敗留下的訊息"
        let store = await Self.makeStore(initial)
        await store.send(.loadData) {
            $0.isLoading = true
            $0.loadError = nil
        }
        await store.receive(\.loadedData) {
            $0.isLoading = false
            $0.summary = Self.sampleSummary
        }
        await MainActor.run { #expect(store.state.loadError == nil) }
    }

    // MARK: - AI insight

    @Test("loadData generates AI insight from the projections when available")
    func testLoadDataAIInsightAvailable() async {
        let insightText = "本月消費偏高，建議減少外食。"
        let capturedSummary = LockIsolated<SpendingSummary?>(nil)
        let store = await Self.makeStore() {
            $0.insightsClient.isAIAvailable = { true }
            $0.insightsClient.generateAIInsight = { summary in
                capturedSummary.setValue(summary)
                return insightText
            }
        }
        await store.send(.loadData)
        await store.receive(\.loadedData) {
            $0.insight = InsightDetail(
                id: $0.insight?.id ?? "",
                title: String(localized: "analysis_ai_insight_title", bundle: .main),
                description: insightText
            )
        }
        #expect(capturedSummary.value?.totalExpense == 500)
        #expect(capturedSummary.value?.totalIncome == 5000)
        #expect(capturedSummary.value?.categoryBreakdown == ["飲食": 500])
        #expect(capturedSummary.value?.periodDescription == BudgetPeriod.monthly.analysisLabel)
    }

    @Test("loadData keeps data and sets insight nil when generateAIInsight throws")
    func testLoadDataAIInsightFailsGracefully() async {
        struct AIError: Error {}
        let store = await Self.makeStore() {
            $0.insightsClient.isAIAvailable = { true }
            $0.insightsClient.generateAIInsight = { _ in throw AIError() }
        }
        await store.send(.loadData)
        await store.receive(\.loadedData) {
            $0.isLoading = false
            $0.insight = nil
            $0.summary = Self.sampleSummary
        }
        // AI 失敗不是載入失敗：資料還在，不該把畫面推去失敗狀態。
        await MainActor.run { #expect(store.state.loadError == nil) }
    }

    // MARK: - Budget gauges

    @Test("budgetMetricsLoaded stores metrics")
    func testBudgetMetricsLoaded() async {
        let metrics = [BudgetGaugeMetrics(id: "b1", categoryName: "飲食", spentAmount: 400, totalBudget: 1000)]
        let store = await TestStore(initialState: AnalysisFeature.State()) { AnalysisFeature() }
        await store.send(.budgetMetricsLoaded(metrics)) { $0.budgetMetrics = metrics }
    }

    @Test("loadData asks insightsClient.budgetGauges with the selected account and keeps its category names")
    func testLoadDataBudgetGaugesAccount() async {
        let metrics = [BudgetGaugeMetrics(id: "b1", categoryName: "飲食", spentAmount: 400, totalBudget: 1000)]
        let capturedAccount = LockIsolated<Account.ID?>(nil)
        var initial = AnalysisFeature.State()
        initial.selectedAccountId = Self.accountId
        let store = await Self.makeStore(initial) {
            $0.insightsClient.budgetGauges = { account in
                capturedAccount.setValue(account)
                return metrics
            }
        }
        await store.send(.loadData)
        await store.receive(\.budgetMetricsLoaded) { $0.budgetMetrics = metrics }   // 收到 metrics 即證明有被呼叫
        #expect(capturedAccount.value == Self.accountId)
        // R3：預算儀表的分類名是 client 給的，reducer 不得改寫（zh-Hant 下圓餅圖與
        // 儀表用不同命名來源就會變成「餐飲」對「Food」）。
        await MainActor.run {
            #expect(store.state.budgetMetrics.first?.categoryName == "飲食")
        }
    }

    @Test("budgetGauges failure yields empty metrics")
    func testBudgetGaugesFailure() async {
        struct GaugeError: Error {}
        var initial = AnalysisFeature.State()
        initial.budgetMetrics = [BudgetGaugeMetrics(id: "stale", categoryName: "x", spentAmount: 1, totalBudget: 2)]
        let store = await Self.makeStore(initial) {
            $0.insightsClient.budgetGauges = { _ in throw GaugeError() }
        }
        await store.send(.loadData)
        await store.receive(\.budgetMetricsLoaded) { $0.budgetMetrics = [] }
    }

    /// `loadData` 的兩條 effect 到達順序不確定，而 non-exhaustive 的 `receive(\.X)` 會把
    /// 排在前面的其他 action **吃掉並套用**——先 `receive(\.loadedData)` 再
    /// `receive(\.budgetMetricsLoaded)` 在順序反過來時，第二個 receive 會永遠等不到而 timeout。
    /// 所以這裡用「兩個都收」的 predicate 版 receive，收兩次，順序無關。
    private static func isLoadDataOutcome(_ action: AnalysisFeature.Action) -> Bool {
        switch action {
        case .loadedData, .budgetMetricsLoaded: return true
        default: return false
        }
    }

    @Test("loadData sends both loadedData and budgetMetricsLoaded")
    func testLoadDataBothEffectsArrive() async {
        let metrics = [BudgetGaugeMetrics(id: "b1", categoryName: "飲食", spentAmount: 400, totalBudget: 1000)]
        let store = await Self.makeStore() {
            $0.insightsClient.budgetGauges = { _ in metrics }
        }
        await store.send(.loadData)
        // 少送任何一條，第二次 receive 就會 timeout——這是這條測試的鑑別點。
        await store.receive(Self.isLoadDataOutcome)
        await store.receive(Self.isLoadDataOutcome)
        await store.finish()
        await MainActor.run {
            #expect(store.state.isLoading == false)
            #expect(store.state.summary == Self.sampleSummary)
            #expect(store.state.budgetMetrics == metrics)
        }
    }

    // MARK: - cancelInFlight（兩條 effect 各一條 cancel id）
    //
    // 鑑別力的來源要挑對，這裡踩過兩個坑：
    //
    // 1. **懸停點必須可取消。** `withCheckedContinuation { _ in }` 在 task 被取消時
    //    **不會**被 resume，effect 於是永遠掛住——有沒有 `.cancellable` 都一樣掛住，
    //    測試恆紅、零鑑別力。要用 `Task.sleep`，它在取消時丟 `CancellationError`。
    //
    // 2. **不能靠 `finish()` 的 timeout 當鑑別點。** `TestStore` 的 timeout 與未接收 action
    //    都走 `reportIssueHelper`，而它受 exhaustivity 管制：`.off`
    //    （`showSkippedAssertions: false`）下訊息被**完全靜音**，測試照樣綠。
    //    所以鑑別點放在 stub 自己記下「我被取消了」，再用 Swift Testing 的 `#expect` 斷言，
    //    `#expect` 不經過 TCA 的 exhaustivity 開關。
    //
    // 兩條都用**參數**（而不是呼叫次序）區分第一條與第二條 effect，
    // 所以不依賴「第一次 send 有沒有來得及讓 effect 起跑」這種時序假設。

    @Test("consecutive loadData: CancelID.load tears down the superseded projection effect")
    func testLoadDataCancelInFlightMainEffect() async {
        let weeklyRange = BudgetPeriod.weekly.dateInterval(containing: Self.now, calendar: Self.calendar)
        let secondSummary = FinancialSummary(totalIncome: 222, totalExpense: 222)
        let firstEffectCancelled = LockIsolated(false)
        let store = await Self.makeStore() {
            $0.insightsClient.financialSummary = { range, _ in
                guard range == weeklyRange else { return secondSummary }
                do {
                    // 懸停到被取消為止。5 秒遠大於整條測試的耗時，所以「沒被取消」
                    // 絕不可能在斷言之前把旗標設起來。
                    try await Task.sleep(for: .seconds(5))
                } catch {
                    firstEffectCancelled.setValue(true)
                    throw error
                }
                return FinancialSummary(totalIncome: 111, totalExpense: 111)
            }
        }
        await store.send(.periodChanged(.weekly)) { $0.selectedPeriod = .weekly }
        await store.send(.periodChanged(.yearly)) { $0.selectedPeriod = .yearly }
        // 只會收到第二次的結果：第一條 effect 被取消之後，TCA 的 `Send` 會
        // `guard !Task.isCancelled`（Effect.swift:207），它送什麼都不會進佇列。
        await store.receive(\.loadedData) {
            $0.isLoading = false
            $0.summary = secondSummary
        }
        await store.finish(timeout: .seconds(1))
        // 鑑別點：拿掉 `.cancellable(id: CancelID.load, cancelInFlight: true)`，
        // 第一條 effect 會一路睡到 5 秒後才結束，這裡必然還是 false。
        #expect(firstEffectCancelled.value)
    }

    @Test("consecutive accountSelected: CancelID.budgets tears down the superseded budget effect")
    func testLoadDataCancelInFlightBudgetEffect() async {
        let accountA = UUID().uuidString
        let accountB = UUID().uuidString
        let second = [BudgetGaugeMetrics(id: "second", categoryName: "飲食", spentAmount: 2, totalBudget: 20)]
        let firstEffectCancelled = LockIsolated(false)
        let store = await Self.makeStore() {
            $0.insightsClient.budgetGauges = { account in
                guard account == accountA else { return second }
                do {
                    try await Task.sleep(for: .seconds(5))
                } catch {
                    firstEffectCancelled.setValue(true)
                    throw error
                }
                return [BudgetGaugeMetrics(id: "first", categoryName: "x", spentAmount: 1, totalBudget: 10)]
            }
        }
        await store.send(.accountSelected(accountA)) { $0.selectedAccountId = accountA }
        await store.send(.accountSelected(accountB)) { $0.selectedAccountId = accountB }
        // 同理只會收到第二次的結果。被取消的第一條即使走到 `?? []` 也送不出去，
        // 所以 `try?` 不會把預算區塊抹成空的。
        await store.receive(\.budgetMetricsLoaded) { $0.budgetMetrics = second }
        await store.finish(timeout: .seconds(1))
        // 鑑別點同上，針對 `CancelID.budgets`。
        #expect(firstEffectCancelled.value)
    }

    // MARK: - Category drill-down

    @Test("categoryTapped fetches expenses scoped to category + account + period closedRange")
    func testCategoryTapped() async {
        let proportion = Self.sampleProportions[0]
        let expected: [Transaction] = [
            Transaction(amount: 300, date: Self.now, note: "午餐", categoryId: Self.categoryId, accountId: Self.accountId, type: .expense),
        ]
        let capturedFilter = LockIsolated<TransactionFilter?>(nil)
        var initial = AnalysisFeature.State()
        initial.selectedAccountId = Self.accountId
        let store = await Self.makeStore(initial) {
            $0.ledgerClient.listAll = { filter in
                capturedFilter.setValue(filter)
                return expected.map { EnrichedTransaction(transaction: $0) }
            }
        }
        await store.send(.categoryTapped(proportion))
        await store.receive(\.categoryTransactionsLoaded) {
            $0.categoryDrilldown = AnalysisFeature.CategoryDrilldownState(categoryName: "飲食", transactions: expected)
        }
        let f = capturedFilter.value
        #expect(f?.categoryIds == Set([Self.categoryId]))
        #expect(f?.accountIds == Set([Self.accountId]))
        #expect(f?.types == Set([.expense]))
        #expect(f?.dateRange == BudgetPeriod.monthly.closedRange(containing: Self.now, calendar: Self.calendar))
    }

    // R2（既有 bug）：未分類桶的 id 是 `CategoryProportion.uncategorizedId`，
    // 不是 UUID。舊版 `UUID(uuidString:)` 拿到 nil 就讓 `categoryIds` 也是 nil，
    // 等於完全不帶分類篩選——點圓餅圖的「其他」會列出該期間的**每一筆支出**。
    // 下面兩條測試在修復前都會收到兩筆（含已分類的那筆）而變紅。

    @Test("categoryTapped on the unassigned bucket drills into uncategorized expenses only")
    func testCategoryTappedUncategorized() async {
        let proportion = CategoryProportion(
            id: CategoryProportion.uncategorizedId,
            name: "其他",
            amount: 150,
            isUnassigned: true
        )
        let uncategorized = Transaction(amount: 150, date: Self.now, note: "雜支", accountId: Self.accountId, type: .expense)
        let categorized = Transaction(amount: 300, date: Self.now, note: "午餐", categoryId: Self.categoryId, accountId: Self.accountId, type: .expense)
        let store = await Self.makeStore() {
            $0.ledgerClient.listAll = { _ in
                [uncategorized, categorized].map { EnrichedTransaction(transaction: $0) }
            }
        }
        await store.send(.categoryTapped(proportion))
        await store.receive(\.categoryTransactionsLoaded) {
            $0.categoryDrilldown = AnalysisFeature.CategoryDrilldownState(
                categoryName: "其他",
                transactions: [uncategorized]
            )
        }
    }

    @Test("categoryTapped treats a non-UUID bucket id as unassigned even without the flag")
    func testCategoryTappedNonUUIDBucketIdWithoutFlag() async {
        // 防守用：`isUnassigned` 是 PR #39 之後才有的欄位、預設 false，舊的呼叫點
        // 可能只帶 id。id 不是 UUID 就一定不是真的分類，同樣要收斂。
        let proportion = CategoryProportion(id: CategoryProportion.uncategorizedId, name: "其他", amount: 150)
        let uncategorized = Transaction(amount: 150, date: Self.now, note: "雜支", accountId: Self.accountId, type: .expense)
        let categorized = Transaction(amount: 300, date: Self.now, note: "午餐", categoryId: Self.categoryId, accountId: Self.accountId, type: .expense)
        let store = await Self.makeStore() {
            $0.ledgerClient.listAll = { _ in
                [uncategorized, categorized].map { EnrichedTransaction(transaction: $0) }
            }
        }
        await store.send(.categoryTapped(proportion))
        await store.receive(\.categoryTransactionsLoaded) {
            $0.categoryDrilldown = AnalysisFeature.CategoryDrilldownState(
                categoryName: "其他",
                transactions: [uncategorized]
            )
        }
    }

    @Test("categoryTapped fetch failure results in empty drilldown")
    func testCategoryTappedFetchFailure() async {
        struct FetchError: Error {}
        let proportion = CategoryProportion(id: UUID().uuidString, name: "飲食", amount: 300)
        let store = await Self.makeStore() {
            $0.ledgerClient.listAll = { _ in throw FetchError() }
        }
        await store.send(.categoryTapped(proportion))
        await store.receive(\.categoryTransactionsLoaded) {
            $0.categoryDrilldown = AnalysisFeature.CategoryDrilldownState(categoryName: "飲食", transactions: [])
        }
    }

    @Test("categoryDrilldownDismissed clears drilldown")
    func testCategoryDrilldownDismissed() async {
        var initial = AnalysisFeature.State()
        initial.categoryDrilldown = AnalysisFeature.CategoryDrilldownState(categoryName: "飲食", transactions: [])
        let store = await TestStore(initialState: initial) { AnalysisFeature() }
        await store.send(.categoryDrilldownDismissed) { $0.categoryDrilldown = nil }
    }

    // MARK: - task

    @Test("task loads active accounts")
    func testTaskLoadsAccounts() async {
        let accounts = [
            Account(name: "現金", type: .cash, icon: "banknote", color: "#34C759", sortOrder: 0),
        ]
        let store = await Self.makeStore() {
            $0.ledgerClient.listActiveAccounts = { accounts }
        }
        await store.send(.task)
        await store.receive(\.accountsLoaded) { $0.accounts = accounts }
    }

    @Test("task forwards aiAssistant.task so the availability gate can resolve")
    func testTaskForwardsAIAssistantTask() async {
        let store = await Self.makeStore() {
            $0.ledgerClient.listActiveAccounts = { [] }
            $0.insightsClient.isAIAvailable = { true }
            // `isAIAvailable = true` 會讓 `.task` 併發觸發的 loadData 走進 AI 分支。
            // `generateAIInsight` 在 `InsightsClient` 沒有預設值 → 未 stub 就是 unimplemented，
            // 會在 store 還活著時記一筆 issue（是否來得及發生取決於排程，所以以前是 flaky）。
            $0.insightsClient.generateAIInsight = { _ in "ok" }
        }
        await store.send(.task)
        await store.receive(\.aiAssistant.task) { $0.aiAssistant.isAvailable = true }
    }
}
