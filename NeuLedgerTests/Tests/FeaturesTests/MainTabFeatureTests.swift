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
}
