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
        }
        await MainActor.run { store.exhaustivity = .off }
        await store.send(.task)
        await store.receive(\.accessory.task)
        await store.receive(\.accessoryBarVisibilityLoaded) {
            $0.showAccessoryBar = false
        }
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

    // MARK: - savedRecurringConfirmation Tests

    @Test("savedRecurringConfirmation calls updateRecurring with updated nextDueDate when id found")
    func savedRecurringConfirmationUpdatesNextDueDate() async {
        let targetId = UUID()
        let newDate = Date(timeIntervalSince1970: 9_999_999)
        var template = RecurringTransaction(
            id: targetId, amount: 5000, note: "水電費",
            categoryId: nil, accountId: UUID().uuidString, toAccountId: nil,
            type: .expense, tags: [], frequency: .monthly,
            nextDueDate: Date(timeIntervalSince1970: 0), isActive: true, createdAt: Date()
        )

        let updatedSpy = LockIsolated<RecurringTransaction?>(nil)
        let store = await TestStore(initialState: MainTabFeature.State()) {
            MainTabFeature()
        } withDependencies: {
            $0.ledgerClient.listRecurring = { [template] in [template] }
            $0.ledgerClient.updateRecurring = { updated in updatedSpy.setValue(updated) }
        }

        await store.send(.dashboard(.delegate(.savedRecurringConfirmation(targetId, newDate))))
        // Wait for the async effect to finish
        await store.finish()

        let updated = updatedSpy.value
        #expect(updated != nil)
        #expect(updated?.id == targetId)
        #expect(updated?.nextDueDate == newDate)
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

    @Test("savedRecurringConfirmation does not call updateRecurring when id not found")
    func savedRecurringConfirmationSkipsWhenIdNotFound() async {
        let missingId = UUID()
        let newDate = Date(timeIntervalSince1970: 9_999_999)
        let otherTemplate = RecurringTransaction(
            id: UUID(), amount: 1000, note: "其他",
            categoryId: nil, accountId: UUID().uuidString, toAccountId: nil,
            type: .expense, tags: [], frequency: .monthly,
            nextDueDate: Date(timeIntervalSince1970: 0), isActive: true, createdAt: Date()
        )

        let updatedSpy = LockIsolated<RecurringTransaction?>(nil)
        let store = await TestStore(initialState: MainTabFeature.State()) {
            MainTabFeature()
        } withDependencies: {
            $0.ledgerClient.listRecurring = { [otherTemplate] in [otherTemplate] }
            $0.ledgerClient.updateRecurring = { updated in updatedSpy.setValue(updated) }
        }

        await store.send(.dashboard(.delegate(.savedRecurringConfirmation(missingId, newDate))))
        await store.finish()

        #expect(updatedSpy.value == nil)
    }
}
