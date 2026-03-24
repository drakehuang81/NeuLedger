import Testing
import Foundation
import ComposableArchitecture
@testable import Features
import Domain

@Suite("BudgetFormFeature Tests")
struct BudgetFormFeatureTests {

    private static let sampleBudget = Budget(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        name: "舊名稱",
        amount: 5000,
        categoryId: nil,
        period: .monthly,
        startDate: Date(timeIntervalSince1970: 0),
        isActive: true
    )

    // MARK: - Validation

    @Test("saveTapped with empty name sets nameError")
    func testSaveTappedEmptyNameSetsError() async {
        let store = await TestStore(
            initialState: BudgetFormFeature.State(mode: .add)
        ) {
            BudgetFormFeature()
        } withDependencies: {
            $0.categoryClient.fetchAll = { [] }
        }

        await store.send(.amountChanged("5000")) {
            $0.amountText = "5000"
        }
        await store.send(.saveTapped) {
            $0.nameError = String(localized: "error_budget_name_empty")
        }
    }

    @Test("saveTapped with zero amount sets amountError")
    func testSaveTappedZeroAmountSetsError() async {
        let store = await TestStore(
            initialState: BudgetFormFeature.State(mode: .add)
        ) {
            BudgetFormFeature()
        } withDependencies: {
            $0.categoryClient.fetchAll = { [] }
        }

        await store.send(.nameChanged("食費")) {
            $0.name = "食費"
        }
        await store.send(.amountChanged("0")) {
            $0.amountText = "0"
        }
        await store.send(.saveTapped) {
            $0.amountError = String(localized: "error_amount_must_be_positive")
        }
    }

    @Test("saveTapped with non-numeric amount sets amountError")
    func testSaveTappedNonNumericAmountSetsError() async {
        let store = await TestStore(
            initialState: BudgetFormFeature.State(mode: .add)
        ) {
            BudgetFormFeature()
        } withDependencies: {
            $0.categoryClient.fetchAll = { [] }
        }

        await store.send(.nameChanged("食費")) {
            $0.name = "食費"
        }
        await store.send(.amountChanged("abc")) {
            $0.amountText = "abc"
        }
        await store.send(.saveTapped) {
            $0.amountError = String(localized: "error_amount_must_be_positive")
        }
    }

    // MARK: - Field updates clear errors

    @Test("nameChanged clears nameError")
    func testNameChangedClearsError() async {
        var initialState = BudgetFormFeature.State(mode: .add)
        initialState.nameError = "some error"

        let store = await TestStore(initialState: initialState) {
            BudgetFormFeature()
        } withDependencies: {
            $0.categoryClient.fetchAll = { [] }
        }

        await store.send(.nameChanged("食費")) {
            $0.name = "食費"
            $0.nameError = nil
        }
    }

    @Test("amountChanged clears amountError")
    func testAmountChangedClearsError() async {
        var initialState = BudgetFormFeature.State(mode: .add)
        initialState.amountError = "some error"

        let store = await TestStore(initialState: initialState) {
            BudgetFormFeature()
        } withDependencies: {
            $0.categoryClient.fetchAll = { [] }
        }

        await store.send(.amountChanged("1000")) {
            $0.amountText = "1000"
            $0.amountError = nil
        }
    }

    // MARK: - Save (add mode)

    @Test("saveTapped with valid inputs adds budget and emits saved delegate")
    func testSaveTappedValidAdds() async {
        let addedBudget: LockIsolated<Budget?> = LockIsolated(nil)
        let store = await TestStore(
            initialState: BudgetFormFeature.State(mode: .add)
        ) {
            BudgetFormFeature()
        } withDependencies: {
            $0.categoryClient.fetchAll = { [] }
            $0.budgetClient.add = { budget in addedBudget.setValue(budget) }
            $0.dismiss = DismissEffect { }
        }

        await store.send(.nameChanged("食費")) { $0.name = "食費" }
        await store.send(.amountChanged("10000")) { $0.amountText = "10000" }
        await store.send(.saveTapped)
        await store.receive(\.savedSuccessfully)
        await store.receive(\.delegate.saved)

        #expect(addedBudget.value?.name == "食費")
        #expect(addedBudget.value?.amount == 10000)
    }

    // MARK: - Save (edit mode)

    @Test("saveTapped in edit mode updates existing budget")
    func testSaveTappedEditUpdates() async {
        let updatedBudget: LockIsolated<Budget?> = LockIsolated(nil)
        let store = await TestStore(
            initialState: BudgetFormFeature.State(mode: .edit(Self.sampleBudget))
        ) {
            BudgetFormFeature()
        } withDependencies: {
            $0.categoryClient.fetchAll = { [] }
            $0.budgetClient.update = { budget in updatedBudget.setValue(budget) }
            $0.dismiss = DismissEffect { }
        }

        await store.send(.nameChanged("新名稱")) { $0.name = "新名稱" }
        await store.send(.saveTapped)
        await store.receive(\.savedSuccessfully)
        await store.receive(\.delegate.saved)

        #expect(updatedBudget.value?.name == "新名稱")
        #expect(updatedBudget.value?.id == Self.sampleBudget.id)
        #expect(updatedBudget.value?.amount == Self.sampleBudget.amount)
    }

    // MARK: - Cancel

    @Test("cancelTapped emits dismissed delegate")
    func testCancelTappedEmitsDismissed() async {
        let store = await TestStore(
            initialState: BudgetFormFeature.State(mode: .add)
        ) {
            BudgetFormFeature()
        } withDependencies: {
            $0.categoryClient.fetchAll = { [] }
            $0.dismiss = DismissEffect { }
        }

        await store.send(.cancelTapped)
        await store.receive(\.delegate.dismissed)
    }

    // MARK: - task loads categories

    @Test("task loads expense categories into availableCategories")
    func testTaskLoadsCategories() async {
        let expenseCategory = Domain.Category(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000010")!,
            name: "食費", icon: "fork.knife", color: "#FF9500",
            type: .expense, sortOrder: 0, isDefault: false
        )
        let incomeCategory = Domain.Category(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000011")!,
            name: "薪資", icon: "banknote", color: "#34C759",
            type: .income, sortOrder: 0, isDefault: false
        )

        let store = await TestStore(
            initialState: BudgetFormFeature.State(mode: .add)
        ) {
            BudgetFormFeature()
        } withDependencies: {
            $0.categoryClient.fetchAll = { [expenseCategory, incomeCategory] }
        }

        await store.send(.task)
        await store.receive(\.categoriesLoaded) {
            // Only expense categories are shown
            $0.availableCategories = [expenseCategory]
        }
    }
}
