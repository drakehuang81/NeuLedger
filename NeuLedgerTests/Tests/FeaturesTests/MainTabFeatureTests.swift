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
            // forwarded to the scoped AccessoryBarFeature — its .task reads aiUseCase + accessoryMode
            $0.aiUseCase.isAvailable = { true }
            $0.userSettingsRepository.string = { _ in "add" }
            $0.userSettingsRepository.bool = { key in
                key.rawValue == SettingsKey.showAccessoryBar.rawValue ? false : key.defaultValue
            }
            $0.notificationAdapter.pendingConfirmations = {
                AsyncStream { $0.finish() }
            }
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
            $0.accountClient.fetchActive = { [] }
            $0.categoryClient.fetchAll = { [] }
            $0.userSettingsRepository.string = { _ in "" }
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
}

@Suite("MainTabFeature — recurring confirmation")
struct MainTabRecurringConfirmationTests {

    @Test("pendingRecurringConfirmationReceived pre-fills dashboard and switches tab")
    func testPendingRecurringConfirmationReceived() async {
        let recurringId = UUID()
        let template = RecurringTransaction(
            id: recurringId, amount: 15000, note: "房租",
            categoryId: nil, accountId: UUID().uuidString, toAccountId: nil,
            type: .expense, tags: [], frequency: .monthly,
            nextDueDate: Date(), isActive: true, createdAt: Date()
        )
        let store = await TestStore(initialState: MainTabFeature.State()) {
            MainTabFeature()
        } withDependencies: {
            $0.recurringTransactionClient.fetchAll = { [template] }
            $0.userSettingsRepository.bool = { _ in false }
            $0.notificationAdapter.pendingConfirmations = {
                AsyncStream { continuation in
                    continuation.finish()
                }
            }
        }
        await MainActor.run {
            store.exhaustivity = .off
        }

        await store.send(.pendingRecurringConfirmationReceived(recurringId))
        await store.receive(\.recurringTemplateFetched) { state in
            #expect(state.dashboard.addTransaction != nil)
            #expect(state.selectedTab == .dashboard)
            #expect(state.pendingRecurringConfirmationId == recurringId)
        }
    }
}
