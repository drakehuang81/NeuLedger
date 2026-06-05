import Testing
import Foundation
import ComposableArchitecture
@testable import Features
import Domain

@Suite("BudgetManagementFeature Tests")
struct BudgetManagementFeatureTests {

    // MARK: - Helpers

    private static let sampleBudget = Budget(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        name: "食費",
        amount: 10000,
        categoryId: nil,
        period: .monthly,
        startDate: Date(timeIntervalSince1970: 0),
        isActive: true
    )

    // MARK: - .task

    @Test(".task loads budgets into state")
    func testTaskLoadsBudgets() async {
        let store = await TestStore(initialState: BudgetManagementFeature.State()) {
            BudgetManagementFeature()
        } withDependencies: {
            $0.planningClient.listAll = { [Self.sampleBudget] }
        }

        await store.send(.task) {
            $0.isLoading = true
        }
        await store.receive(\.budgetsLoaded) {
            $0.isLoading = false
            $0.budgets = [Self.sampleBudget]
        }
    }

    // MARK: - toggleActive

    @Test("toggleActive flips isActive and reloads")
    func testToggleActive() async {
        let updated: LockIsolated<Budget?> = LockIsolated(nil)
        var initialState = BudgetManagementFeature.State()
        initialState.budgets = [Self.sampleBudget]

        let store = await TestStore(initialState: initialState) {
            BudgetManagementFeature()
        } withDependencies: {
            $0.planningClient.update = { budget in updated.setValue(budget) }
            $0.planningClient.listAll = { [Self.sampleBudget] }
        }

        await store.send(.toggleActive(Self.sampleBudget))
        await store.receive(\.budgetsLoaded)
        #expect(updated.value?.isActive == false)
    }

    // MARK: - delete flow

    @Test("deleteRequested presents confirmation alert")
    func testDeleteRequestedShowsAlert() async {
        let id = Self.sampleBudget.id
        var initialState = BudgetManagementFeature.State()
        initialState.budgets = [Self.sampleBudget]

        let store = await TestStore(initialState: initialState) {
            BudgetManagementFeature()
        } withDependencies: {
            $0.planningClient.listAll = { [] }
        }

        await store.send(.deleteRequested(id)) {
            $0.alert = AlertState {
                TextState(String(localized: "alert_delete_budget"))
            } actions: {
                ButtonState(role: .destructive, action: .deleteConfirmed(id)) {
                    TextState(String(localized: "common_delete"))
                }
                ButtonState(role: .cancel) {
                    TextState(String(localized: "common_cancel"))
                }
            } message: {
                TextState(String(localized: "alert_delete_budget_message"))
            }
        }
    }

    @Test("deleteConfirmed removes budget and reloads")
    func testDeleteConfirmedRemovesBudget() async {
        let deletedId: LockIsolated<Budget.ID?> = LockIsolated(nil)
        let id = Self.sampleBudget.id
        var initialState = BudgetManagementFeature.State()
        initialState.budgets = [Self.sampleBudget]
        initialState.alert = AlertState {
            TextState(String(localized: "alert_delete_budget"))
        } actions: {
            ButtonState(role: .destructive, action: BudgetManagementFeature.Action.Alert.deleteConfirmed(id)) {
                TextState(String(localized: "common_delete"))
            }
            ButtonState(role: .cancel) {
                TextState(String(localized: "common_cancel"))
            }
        } message: {
            TextState(String(localized: "alert_delete_budget_message"))
        }

        let store = await TestStore(initialState: initialState) {
            BudgetManagementFeature()
        } withDependencies: {
            $0.planningClient.delete = { budgetId in deletedId.setValue(budgetId) }
            $0.planningClient.listAll = { [] }
        }

        await store.send(.alert(.presented(.deleteConfirmed(id)))) {
            $0.alert = nil
        }
        await store.receive(\.budgetsLoaded) {
            $0.budgets = []
        }
        #expect(deletedId.value == id)
    }
}
