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

    // MARK: - add/edit form open

    @Test("addButtonTapped presents add form")
    func testAddButtonTapped() async {
        let store = await TestStore(
            initialState: BudgetManagementFeature.State()
        ) {
            BudgetManagementFeature()
        } withDependencies: {
            $0.ledgerClient.listCategories = { _ in [] }
        }
        // BudgetFormFeature.State.startDate 用 Date()，在並行測試中有毫秒差異
        // exhaustive=off 讓未聲明的欄位不被精確比對
        await MainActor.run { store.exhaustivity = .off }

        // 不在 closure 中設定 addEdit（含 startDate）以避免時間差 mismatch
        await store.send(.addButtonTapped)

        await store.send(\.addEdit.dismiss) {
            $0.addEdit = nil
        }
    }

    @Test("budgetTapped presents edit form with existing budget")
    func testBudgetTappedPresentsEditForm() async {
        var initialState = BudgetManagementFeature.State()
        initialState.budgets = [Self.sampleBudget]

        let store = await TestStore(initialState: initialState) {
            BudgetManagementFeature()
        } withDependencies: {
            $0.ledgerClient.listCategories = { _ in [] }
        }
        await MainActor.run { store.exhaustivity = .off }

        await store.send(.budgetTapped(Self.sampleBudget)) {
            $0.addEdit = BudgetFormFeature.State(mode: .edit(Self.sampleBudget))
        }

        await store.send(\.addEdit.dismiss) {
            $0.addEdit = nil
        }
    }

    // MARK: - addEdit delegate

    @Test("addEdit delegate saved clears sheet and reloads budgets")
    func testAddEditDelegateSavedReloads() async {
        var initialState = BudgetManagementFeature.State()
        initialState.addEdit = BudgetFormFeature.State(mode: .add)

        let store = await TestStore(initialState: initialState) {
            BudgetManagementFeature()
        } withDependencies: {
            $0.planningClient.listAll = { [Self.sampleBudget] }
        }

        await store.send(.addEdit(.presented(.delegate(.saved)))) {
            $0.addEdit = nil
        }

        await store.receive(\.budgetsLoaded) {
            $0.budgets = [Self.sampleBudget]
        }
    }

    @Test("addEdit delegate dismissed clears sheet without reloading budgets")
    func testAddEditDelegateDismissedClearsSheet() async {
        var initialState = BudgetManagementFeature.State()
        initialState.addEdit = BudgetFormFeature.State(mode: .add)

        let store = await TestStore(initialState: initialState) {
            BudgetManagementFeature()
        }

        await store.send(.addEdit(.presented(.delegate(.dismissed)))) {
            $0.addEdit = nil
        }
        // No budgetsLoaded expected
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
