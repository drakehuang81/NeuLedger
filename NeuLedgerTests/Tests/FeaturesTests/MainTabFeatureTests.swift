import ComposableArchitecture
import Domain
import Foundation
import Testing
@testable import Features

@Suite("MainTabFeature — task & accessory routing")
struct MainTabFeatureTests {

    @Test("task forwards lifecycle to accessory and loads showAccessoryBar")
    func taskForwardsLifecycleAndLoadsAccessoryBar() async {
        let store = await TestStore(initialState: MainTabFeature.State()) {
            MainTabFeature()
        } withDependencies: {
            // forwarded to the scoped AccessoryBarFeature — its .task reads captureClient + accessoryMode
            $0.captureClient.isAvailable = { true }
            $0.platformClient.accessoryMode = { .add }
            // MainTab's .task reads showAccessoryBar from platformClient
            $0.platformClient.showAccessoryBar = { false }
            // .task 也會送 recurringTickRequested
            $0.ledgerClient.tick = { 0 }
        }
        await MainActor.run { store.exhaustivity = .off }
        await store.send(.task)
        await store.receive(\.accessory.task)
        await store.receive(\.accessoryBarVisibilityLoaded) {
            $0.showAccessoryBar = false
        }
        await store.receive(\.recurringTicked)
        await store.finish()
    }

    @Test("contextActionRequested on dashboard routes to dashboard add")
    func contextActionRoutesDashboard() async {
        var initial = MainTabFeature.State()
        initial.selectedTab = .dashboard
        let store = await TestStore(initialState: initial) {
            MainTabFeature()
        } withDependencies: {
            $0.date = .constant(Date(timeIntervalSince1970: 0))
        }
        await MainActor.run { store.exhaustivity = .off }
        await store.send(.accessory(.delegate(.contextActionRequested)))
        await store.receive(\.dashboard.addTransactionButtonTapped) { state in
            #expect(state.dashboard.addTransaction?.mode == .add(.expense))
        }
    }

    @Test("contextActionRequested on transactions routes to transactions add")
    func contextActionRoutesTransactions() async {
        var initial = MainTabFeature.State()
        initial.selectedTab = .transactions
        let store = await TestStore(initialState: initial) {
            MainTabFeature()
        }
        await MainActor.run { store.exhaustivity = .off }
        await store.send(.accessory(.delegate(.contextActionRequested)))
        await store.receive(\.transactions.contextActionTapped) { state in
            #expect(state.transactions.addTransaction?.mode == .add(.expense))
        }
    }

    @Test("transactionExtracted delegate on dashboard opens AddTransaction")
    func transactionExtractedRoutesDashboard() async {
        let extracted = ExtractedTransaction(amount: 150, suggestedCategory: "食物", description: "午餐", type: "expense")
        let fixedDate = Date(timeIntervalSince1970: 0)
        var initial = MainTabFeature.State()
        initial.selectedTab = .dashboard
        let store = await TestStore(initialState: initial) {
            MainTabFeature()
        } withDependencies: {
            $0.ledgerClient.listActiveAccounts = { [] }
            $0.ledgerClient.listCategories = { _ in [] }
            $0.userSettingsAdapter.string = { _ in "" }
            $0.date = .constant(fixedDate)
        }
        await store.send(.accessory(.delegate(.transactionExtracted(extracted))))
        await store.receive(\.dashboard.addTransactionWithPrefilledData) {
            $0.dashboard.addTransaction = AddTransactionFeature.State(mode: .addPrefilled(extracted), date: fixedDate)
        }
    }

    @Test("transactionExtracted delegate on transactions opens AddTransaction")
    func transactionExtractedRoutesTransactions() async {
        let extracted = ExtractedTransaction(amount: 150, suggestedCategory: "食物", description: "午餐", type: "expense")
        var initial = MainTabFeature.State()
        initial.selectedTab = .transactions
        let store = await TestStore(initialState: initial) {
            MainTabFeature()
        }
        await MainActor.run { store.exhaustivity = .off }
        await store.send(.accessory(.delegate(.transactionExtracted(extracted))))
        await store.receive(\.transactions.addTransactionWithPrefilledData) { state in
            #expect(state.transactions.addTransaction?.mode == .addPrefilled(extracted))
        }
    }

    // MARK: - B3 補強：delegate 同步

    @Test("settings.delegate.accessoryBarVisibilityChanged syncs showAccessoryBar to MainTab state")
    func settingsDelegateAccessoryBarVisibilityChangedSyncsState() async {
        var initial = MainTabFeature.State()
        initial.showAccessoryBar = true

        let store = await TestStore(initialState: initial) {
            MainTabFeature()
        }

        await store.send(.settings(.delegate(.accessoryBarVisibilityChanged(false)))) {
            $0.showAccessoryBar = false
        }
    }

    @Test("dashboard.delegate.seeAllTransactionsTapped switches selectedTab to .transactions")
    func dashboardDelegateSeeAllTransactionsTappedSwitchesTab() async {
        var initial = MainTabFeature.State()
        initial.selectedTab = .dashboard

        let store = await TestStore(initialState: initial) {
            MainTabFeature()
        }

        await store.send(.dashboard(.delegate(.seeAllTransactionsTapped))) {
            $0.selectedTab = .transactions
        }
    }

    // MARK: - B4 補強：tabSelected 連動 isAccessoryVisible

    @Test("tabSelected(.settings) 在 path 為空時 isAccessoryVisible = true")
    func tabSelectedSettingsPathEmptyIsAccessoryVisible() async {
        var initial = MainTabFeature.State()
        initial.selectedTab = .dashboard
        initial.showAccessoryBar = true

        let store = await TestStore(initialState: initial) {
            MainTabFeature()
        }

        await store.send(.tabSelected(.settings)) {
            $0.selectedTab = .settings
            #expect($0.isAccessoryVisible == true) // settings.path is empty
        }
    }

    @Test("tabSelected(.settings) 在 settings.path 非空時 isAccessoryVisible = false")
    func tabSelectedSettingsPathNonEmptyIsAccessoryHidden() async {
        var initial = MainTabFeature.State()
        initial.selectedTab = .dashboard
        initial.showAccessoryBar = true
        // Push an AccountManagement state into settings.path
        initial.settings.path.append(.accountManagement(AccountManagementFeature.State()))

        let store = await TestStore(initialState: initial) {
            MainTabFeature()
        }

        await store.send(.tabSelected(.settings)) {
            $0.selectedTab = .settings
            #expect($0.isAccessoryVisible == false) // settings.path 非空
        }
    }

    // MARK: - 週期交易自動入帳（health-audit A2）

    private struct TickStubError: LocalizedError { var errorDescription: String? { "boom" } }

    @Test("a tick that recorded something refreshes the dashboard and the transactions tab")
    func testTickRefreshesBothTabsWhenSomethingWasRecorded() async {
        let store = await TestStore(initialState: MainTabFeature.State()) {
            MainTabFeature()
        } withDependencies: {
            $0.date = .constant(Date(timeIntervalSince1970: 0))
            $0.ledgerClient.tick = { 2 }
            // dashboard 的 pulledToRefresh 會打六條 effect
            $0.ledgerClient.listActiveAccounts = { [] }
            $0.ledgerClient.balances           = { [:] }
            $0.ledgerClient.listAll            = { _ in [] }
            $0.ledgerClient.listCategories     = { _ in [] }
            $0.insightsClient.todayStats       = { _ in StatsSnapshot(today: 0, week: 0, savingsPercentage: 0) }
            $0.insightsClient.weeklySparkline  = { _ in [] }
            $0.insightsClient.generateInsights = { _ in [] }
            // Task 6（commit 51b88da）幫 insightsEffect 加了這支呼叫，這條既有測試
            // 沒跟著補 stub——carry-over 缺口，team-lead 掃過完整 scheme 後核准隨手補上。
            $0.insightsClient.categoryProportions = { _ in [] }
        }
        await MainActor.run { store.exhaustivity = .off }

        await store.send(.recurringTickRequested)
        await store.receive(\.recurringTicked)
        await store.receive(\.dashboard.pulledToRefresh)
        await store.receive(\.transactions.task)
        await store.finish()
    }

    @Test("a tick that recorded nothing does not refresh the tabs")
    func testTickWithZeroDoesNotRefresh() async {
        let store = await TestStore(initialState: MainTabFeature.State()) {
            MainTabFeature()
        } withDependencies: {
            $0.ledgerClient.tick = { 0 }
        }
        await MainActor.run { store.exhaustivity = .off }

        await store.send(.recurringTickRequested)
        await store.receive(\.recurringTicked)
        // 沒有任何 dashboard / transactions 的重載：若 reducer 送了，未覆寫的
        // ledgerClient.listAll 等會以 unimplemented 讓這條測試失敗。
        await store.finish()
    }

    @Test("returning to the foreground runs the tick again")
    func testScenePhaseActiveRunsTick() async {
        let ticks = LockIsolated(0)
        let store = await TestStore(initialState: MainTabFeature.State()) {
            MainTabFeature()
        } withDependencies: {
            $0.ledgerClient.tick = { ticks.withValue { $0 += 1 }; return 0 }
        }
        await MainActor.run { store.exhaustivity = .off }

        await store.send(.scenePhaseBecameActive)
        await store.receive(\.recurringTickRequested)
        await store.receive(\.recurringTicked)
        await store.finish()
        #expect(ticks.value == 1)
    }

    @Test("a failing tick surfaces recurringTickFailed and refreshes nothing")
    func testTickFailure() async {
        let store = await TestStore(initialState: MainTabFeature.State()) {
            MainTabFeature()
        } withDependencies: {
            $0.ledgerClient.tick = { throw TickStubError() }
        }
        await MainActor.run { store.exhaustivity = .off }

        await store.send(.recurringTickRequested)
        await store.receive(\.recurringTickFailed)
        await store.finish()
    }

    // MARK: - W1（final-fix-brief）：cancelInFlight 與 Client 層閘門互相抵消
    //
    // 用 gate（AsyncStream，見 AccessoryBarFeatureTests.testDismissCancelsExtraction 的既有寫法）
    // 而不是 Task.yield() 控制第一條 tick 的完成時機：第一條卡在 gate（模擬冷啟動時仍在跑），
    // 第二條立刻由模擬閘門回 0；確定第二條已經處理完，才放行第一條並斷言它的結果沒被吃掉。
    // 用顯式 gate 取代 Task.yield() 是為了讓排序在系統負載高（跑整個 suite）時仍是決定性的——
    // Task.yield() 次數在並行跑很多測試時無法保證第一條會先完成，實測在完整 suite 下會偶發假紅。

    @Test("a second tick request does not cancel the first one's refresh")
    func testSecondTickRequestDoesNotCancelTheFirstRefresh() async {
        let calls = LockIsolated(0)
        let (gate, gateContinuation) = AsyncStream<Void>.makeStream()
        let store = await TestStore(initialState: MainTabFeature.State()) {
            MainTabFeature()
        } withDependencies: {
            $0.date = .constant(Date(timeIntervalSince1970: 0))
            // 模擬 RecurringTickGate：先到者等測試放行才回傳真實筆數，後到者立刻被擋下回 0。
            $0.ledgerClient.tick = {
                let n = calls.withValue { c -> Int in c += 1; return c }
                if n > 1 { return 0 }
                for await _ in gate { break }
                return 2
            }
            // dashboard 的 pulledToRefresh 會打六條 effect
            $0.ledgerClient.listActiveAccounts = { [] }
            $0.ledgerClient.balances           = { [:] }
            $0.ledgerClient.listAll            = { _ in [] }
            $0.ledgerClient.listCategories     = { _ in [] }
            $0.insightsClient.todayStats       = { _ in StatsSnapshot(today: 0, week: 0, savingsPercentage: 0) }
            $0.insightsClient.weeklySparkline  = { _ in [] }
            $0.insightsClient.generateInsights = { _ in [] }
            // Task 6（commit 51b88da）幫 insightsEffect 加了這支呼叫，這條既有測試
            // 沒跟著補 stub——carry-over 缺口，team-lead 掃過完整 scheme 後核准隨手補上。
            $0.insightsClient.categoryProportions = { _ in [] }
        }
        await MainActor.run { store.exhaustivity = .off }

        // 第一條 tick 請求：closure 卡在 gate，尚未回傳（模擬冷啟動時仍在跑的第一條 tick）。
        await store.send(.recurringTickRequested)
        // 第二條請求（scenePhase 回前景）：閘門擋下回 0。若 cancelInFlight 還在，這裡會先取消第一條。
        await store.send(.scenePhaseBecameActive)
        await store.receive(\.recurringTickRequested)
        await store.receive(\.recurringTicked)

        // 放行第一條，讓它把真正補到的筆數送出來。
        gateContinuation.yield(())
        gateContinuation.finish()

        // 關鍵斷言：第一條的結果沒有被第二條取消掉——收得到帶正值的 recurringTicked 與後續刷新。
        await store.receive(\.recurringTicked)
        await store.receive(\.dashboard.pulledToRefresh)
        await store.finish()
        #expect(calls.value == 2, "兩次請求都要真的呼叫 tick，第二次由閘門擋下")
    }

    // MARK: - Dashboard 與交易分頁互相同步（health-audit A8）
    //
    // 現況：兩個 child 各自只重載自己，MainTab 不做跨 tab 轉發；TransactionsView 的 `.task`
    // 在 TabView 裡只會在該 tab 內容首次建立時觸發一次。結果是在 Dashboard 新增一筆 → 切到
    // 交易分頁 → 新那筆不在列表上，反向亦然。R7：切 tab 時重載目標 tab，且刻意不送 `.task`——
    // 它會把 phase 轉 loading／設 isLoading，在已經有資料的畫面上閃一片骨架或轉圈。

    @Test("switching to the transactions tab reloads it, so a dashboard change shows up")
    func testSwitchingToTransactionsReloads() async throws {
        let store = await TestStore(initialState: MainTabFeature.State()) {
            MainTabFeature()
        } withDependencies: {
            $0.date = .constant(Date(timeIntervalSince1970: 1_700_000_000))
            $0.ledgerClient.listAll = { _ in [] }
            $0.ledgerClient.listCategories = { _ in [] }
            $0.ledgerClient.tick = { 0 }
        }
        await MainActor.run { store.exhaustivity = .off }

        // 起始就是 .dashboard，所以切到 .transactions 是真的換 tab
        await store.send(.tabSelected(.transactions)) {
            $0.selectedTab = .transactions
        }
        await store.receive(\.transactions.refreshRequested)
        // 刻意不用 `skipReceivedActions()`：它在 action 佇列已被 `receive` 耗盡時
        // 會誤判成失敗（Task 3 為此修過三條既有測試）。`finish()` 本身就會等所有
        // effect 收尾。
        await store.finish()
    }

    @Test("switching back to the dashboard tab reloads it too")
    func testSwitchingToDashboardReloads() async throws {
        var initial = MainTabFeature.State()
        initial.selectedTab = .transactions
        let store = await TestStore(initialState: initial) {
            MainTabFeature()
        } withDependencies: {
            $0.date = .constant(Date(timeIntervalSince1970: 1_700_000_000))
            $0.ledgerClient.listAll = { _ in [] }
            $0.ledgerClient.balances = { [:] }
            $0.ledgerClient.listActiveAccounts = { [] }
            $0.ledgerClient.listCategories = { _ in [] }
            $0.insightsClient.todayStats = { _ in .zero }
            $0.insightsClient.categoryProportions = { _ in [] }
            $0.insightsClient.generateInsights = { _ in [] }
            $0.insightsClient.weeklySparkline = { _ in [] }
            $0.ledgerClient.tick = { 0 }
        }
        await MainActor.run { store.exhaustivity = .off }

        await store.send(.tabSelected(.dashboard)) {
            $0.selectedTab = .dashboard
        }
        await store.receive(\.dashboard.pulledToRefresh)
        // 同上：不要 `skipReceivedActions()`。
        await store.finish()
    }

    @Test("re-tapping the tab you are already on does not reload")
    func testReselectingTheSameTabDoesNotReload() async throws {
        let store = await TestStore(initialState: MainTabFeature.State()) {
            MainTabFeature()
        } withDependencies: {
            $0.date = .constant(Date(timeIntervalSince1970: 1_700_000_000))
        }
        // 這條要 exhaustive：它的全部意義就是「沒有任何 effect 被送出」。
        await store.send(.tabSelected(.dashboard))
        await store.finish()
    }
}
