import Testing
import Foundation
import ComposableArchitecture
@testable import Features
import Domain

@Suite("AddEditCategoryFeature Tests")
struct AddEditCategoryFeatureTests {

    // MARK: - Shared fixtures

    private static let customExpenseCategory = Domain.Category(
        id: UUID(uuidString: "20000000-0000-0000-0000-000000000001")!,
        name: "娛樂",
        icon: "gamecontroller.fill",
        color: "#5856D6",
        type: .expense,
        sortOrder: 3,
        isDefault: false
    )

    private static let defaultIncomeCategory = Domain.Category(
        id: UUID(uuidString: "20000000-0000-0000-0000-000000000002")!,
        name: "薪資",
        icon: "briefcase.fill",
        color: "#34C759",
        type: .income,
        sortOrder: 0,
        isDefault: true
    )

    // MARK: - State init — add mode

    @Test("add mode .expense sets correct defaults")
    func testAddModeExpenseDefaults() async {
        let state = AddEditCategoryFeature.State(mode: .add(.expense))
        #expect(state.type == .expense)
        #expect(state.name == "")
        #expect(state.icon == "tag.fill")
        #expect(state.colorHex == "#007AFF")
        #expect(state.isDefault == false)
        #expect(state.nameError == nil)
    }

    @Test("add mode .income sets type to income")
    func testAddModeIncomeDefaultsType() async {
        let state = AddEditCategoryFeature.State(mode: .add(.income))
        #expect(state.type == .income)
    }

    // MARK: - State init — edit mode

    @Test("edit mode copies category's fields")
    func testEditModeCopiesCategoryValues() async {
        let cat = Self.customExpenseCategory
        let state = AddEditCategoryFeature.State(mode: .edit(cat))
        #expect(state.name == cat.name)
        #expect(state.icon == cat.icon)
        #expect(state.colorHex == cat.color)
        #expect(state.type == cat.type)
        #expect(state.isDefault == cat.isDefault)
        #expect(state.nameError == nil)
    }

    @Test("edit mode with default category sets isDefault true")
    func testEditModeDefaultCategoryIsDefault() async {
        let state = AddEditCategoryFeature.State(mode: .edit(Self.defaultIncomeCategory))
        #expect(state.isDefault == true)
    }

    // MARK: - Save .add success

    @Test("save .add calls createCategory with correct fields including type and emits delegate.saved")
    func testSaveAddSuccess() async {
        let created = LockIsolated<Domain.Category?>(nil)

        let store = await TestStore(
            initialState: AddEditCategoryFeature.State(mode: .add(.expense))
        ) {
            AddEditCategoryFeature()
        } withDependencies: {
            $0.ledgerClient.createCategory = { created.setValue($0) }
            $0.dismiss = DismissEffect {}
        }

        await store.send(.nameChanged("購物")) { $0.name = "購物" }
        await store.send(.iconChanged("cart.fill")) { $0.icon = "cart.fill" }
        await store.send(.colorHexChanged("#FF9500")) { $0.colorHex = "#FF9500" }
        await store.send(.typeChanged(.expense)) // stays expense
        await store.send(.saveTapped)
        await store.receive(\.savedSuccessfully)
        await store.receive(\.delegate.saved)

        #expect(created.value?.name == "購物")
        #expect(created.value?.icon == "cart.fill")
        #expect(created.value?.color == "#FF9500")
        #expect(created.value?.type == .expense)
        #expect(created.value?.isDefault == false)
    }

    @Test("save .add income preserves income type in created category")
    func testSaveAddIncomeType() async {
        let created = LockIsolated<Domain.Category?>(nil)

        let store = await TestStore(
            initialState: AddEditCategoryFeature.State(mode: .add(.income))
        ) {
            AddEditCategoryFeature()
        } withDependencies: {
            $0.ledgerClient.createCategory = { created.setValue($0) }
            $0.dismiss = DismissEffect {}
        }

        await store.send(.nameChanged("獎金")) { $0.name = "獎金" }
        await store.send(.saveTapped)
        await store.receive(\.savedSuccessfully)
        await store.receive(\.delegate.saved)

        #expect(created.value?.type == .income)
    }

    // MARK: - Save .edit success

    @Test("save .edit calls updateCategory preserving id and isDefault, updating other fields")
    func testSaveEditSuccess() async {
        let updated = LockIsolated<Domain.Category?>(nil)
        let original = Self.customExpenseCategory

        let store = await TestStore(
            initialState: AddEditCategoryFeature.State(mode: .edit(original))
        ) {
            AddEditCategoryFeature()
        } withDependencies: {
            $0.ledgerClient.updateCategory = { updated.setValue($0) }
            $0.dismiss = DismissEffect {}
        }

        await store.send(.nameChanged("電影")) { $0.name = "電影" }
        await store.send(.iconChanged("film")) { $0.icon = "film" }
        await store.send(.colorHexChanged("#AF52DE")) { $0.colorHex = "#AF52DE" }
        await store.send(.saveTapped)
        await store.receive(\.savedSuccessfully)
        await store.receive(\.delegate.saved)

        #expect(updated.value?.id == original.id)
        #expect(updated.value?.name == "電影")
        #expect(updated.value?.icon == "film")
        #expect(updated.value?.color == "#AF52DE")
        #expect(updated.value?.type == original.type)
        #expect(updated.value?.sortOrder == original.sortOrder)
        #expect(updated.value?.isDefault == original.isDefault)
    }

    // MARK: - Name validation failure

    @Test("saveTapped with empty name sets nameError and does NOT call createCategory")
    func testSaveEmptyNameSetsError() async {
        let created = LockIsolated<Domain.Category?>(nil)

        let store = await TestStore(
            initialState: AddEditCategoryFeature.State(mode: .add(.expense))
        ) {
            AddEditCategoryFeature()
        } withDependencies: {
            $0.ledgerClient.createCategory = { created.setValue($0) }
        }

        await store.send(.saveTapped) {
            $0.nameError = String(localized: "error_category_name_empty")
        }

        #expect(created.value == nil)
    }

    @Test("nameChanged clears nameError")
    func testNameChangedClearsError() async {
        var initialState = AddEditCategoryFeature.State(mode: .add(.expense))
        initialState.nameError = "stale error"

        let store = await TestStore(initialState: initialState) {
            AddEditCategoryFeature()
        }

        await store.send(.nameChanged("新分類")) {
            $0.name = "新分類"
            $0.nameError = nil
        }
    }

    // MARK: - cancelTapped

    @Test("cancelTapped emits delegate.dismissed")
    func testCancelTapped() async {
        let store = await TestStore(
            initialState: AddEditCategoryFeature.State(mode: .add(.expense))
        ) {
            AddEditCategoryFeature()
        } withDependencies: {
            $0.dismiss = DismissEffect {}
        }

        await store.send(.cancelTapped)
        await store.receive(\.delegate.dismissed)
    }

    // MARK: - Setters

    @Test("nameChanged updates state.name")
    func testNameChanged() async {
        let store = await TestStore(
            initialState: AddEditCategoryFeature.State(mode: .add(.expense))
        ) {
            AddEditCategoryFeature()
        }

        await store.send(.nameChanged("餐廳")) {
            $0.name = "餐廳"
        }
    }

    @Test("iconChanged updates state.icon")
    func testIconChanged() async {
        let store = await TestStore(
            initialState: AddEditCategoryFeature.State(mode: .add(.expense))
        ) {
            AddEditCategoryFeature()
        }

        await store.send(.iconChanged("fork.knife")) {
            $0.icon = "fork.knife"
        }
    }

    @Test("colorHexChanged updates state.colorHex")
    func testColorHexChanged() async {
        let store = await TestStore(
            initialState: AddEditCategoryFeature.State(mode: .add(.expense))
        ) {
            AddEditCategoryFeature()
        }

        await store.send(.colorHexChanged("#FF3B30")) {
            $0.colorHex = "#FF3B30"
        }
    }

    @Test("typeChanged updates state.type for non-default category")
    func testTypeChangedForNonDefault() async {
        let store = await TestStore(
            initialState: AddEditCategoryFeature.State(mode: .add(.expense))
        ) {
            AddEditCategoryFeature()
        }

        await store.send(.typeChanged(.income)) {
            $0.type = .income
        }
    }

    @Test("typeChanged is ignored for default category (isDefault guard)")
    func testTypeChangedIgnoredForDefault() async {
        let store = await TestStore(
            initialState: AddEditCategoryFeature.State(mode: .edit(Self.defaultIncomeCategory))
        ) {
            AddEditCategoryFeature()
        }

        // isDefault == true → guard returns .none, no state mutation
        await store.send(.typeChanged(.expense))
        // TestStore strict mode: no state change expected, no actions expected
    }
}
