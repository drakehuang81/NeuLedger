import Testing
import Foundation
import ComposableArchitecture
import Domain
@testable import Features

@Suite("CategoryManagementFeature Tests")
struct CategoryManagementFeatureTests {

    // MARK: - Helpers

    private static let foodCategory = Domain.Category(
        id: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!,
        name: "飲食", icon: "fork.knife", color: "#FF3B30", type: .expense, sortOrder: 0, isDefault: true
    )
    private static let transportCategory = Domain.Category(
        id: UUID(uuidString: "10000000-0000-0000-0000-000000000002")!,
        name: "交通", icon: "car.fill", color: "#FF9500", type: .expense, sortOrder: 1, isDefault: true
    )
    private static let salaryCategory = Domain.Category(
        id: UUID(uuidString: "10000000-0000-0000-0000-000000000003")!,
        name: "薪資", icon: "briefcase.fill", color: "#34C759", type: .income, sortOrder: 0, isDefault: true
    )
    private static let customExpenseCategory = Domain.Category(
        id: UUID(uuidString: "10000000-0000-0000-0000-000000000004")!,
        name: "自訂支出", icon: "tag.fill", color: "#5856D6", type: .expense, sortOrder: 2, isDefault: false
    )

    // MARK: - Load Categories

    @Test("task loads all categories sorted by sortOrder")
    func testTaskLoadsCategoriesSorted() async throws {
        let allCategories = [Self.salaryCategory, Self.transportCategory, Self.foodCategory, Self.customExpenseCategory]

        let store = await TestStore(
            initialState: CategoryManagementFeature.State()
        ) {
            CategoryManagementFeature()
        } withDependencies: {
            $0.ledgerClient.listCategories = { _ in allCategories }
        }

        await store.send(.task) { $0.isLoading = true }

        await store.receive(\.categoriesLoaded) {
            $0.isLoading = false
            // Swift's `sorted` is stable: salary(0) before food(0), then transport(1), then custom(2)
            $0.categories = [Self.salaryCategory, Self.foodCategory, Self.transportCategory, Self.customExpenseCategory]
        }
    }

    // MARK: - Segment Switching

    @Test("selectedTypeChanged filters categories by type")
    @MainActor
    func testSelectedTypeChangedFiltersCategories() async throws {
        var initialState = CategoryManagementFeature.State()
        initialState.categories = [Self.foodCategory, Self.transportCategory, Self.salaryCategory]

        let store = TestStore(initialState: initialState) {
            CategoryManagementFeature()
        }

        #expect(store.state.filteredCategories.count == 2) // default: expense

        await store.send(.selectedTypeChanged(.income)) {
            $0.selectedType = .income
        }

        #expect(store.state.filteredCategories.count == 1)
        #expect(store.state.filteredCategories.first?.name == "薪資")
    }

    @Test("selectedTypeChanged ignores .transfer type")
    func testSelectedTypeChangedIgnoresTransfer() async throws {
        let store = await TestStore(
            initialState: CategoryManagementFeature.State()
        ) {
            CategoryManagementFeature()
        }

        await store.send(.selectedTypeChanged(.transfer))
        // No state change expected — transfer is guarded
    }

    // MARK: - Add Category

    @Test("addButtonTapped presents add form defaulting to current selectedType")
    func testAddButtonTapped() async throws {
        var initialState = CategoryManagementFeature.State()
        initialState.selectedType = .income

        let store = await TestStore(initialState: initialState) {
            CategoryManagementFeature()
        }

        await store.send(.addButtonTapped) {
            $0.addEdit = AddEditCategoryFeature.State(mode: .add(.income))
        }

        // Dismiss the presented sheet so the @Presents dismiss-listener
        // effect tears down before the test ends.
        await store.send(\.addEdit.dismiss) {
            $0.addEdit = nil
        }
    }

    // MARK: - Delete Custom Category

    @Test("deleteRequested for custom category shows confirmation alert")
    func testDeleteRequestedForCustomCategory() async throws {
        let id = Self.customExpenseCategory.id
        var initialState = CategoryManagementFeature.State()
        initialState.categories = [Self.customExpenseCategory]

        let store = await TestStore(initialState: initialState) {
            CategoryManagementFeature()
        }

        await store.send(.deleteRequested(id)) {
            $0.alert = AlertState {
                TextState(String(localized: "alert_delete_category"))
            } actions: {
                ButtonState(role: .destructive, action: CategoryManagementFeature.Action.Alert.deleteConfirmed(id)) {
                    TextState(String(localized: "common_delete"))
                }
                ButtonState(role: .cancel) {
                    TextState(String(localized: "common_cancel"))
                }
            } message: {
                TextState(String(format: String(localized: "alert_delete_category_message_name %@"), Self.customExpenseCategory.name))
            }
        }
    }

    // MARK: - Reject Delete of Default Category

    @Test("deleteRequested for default category does nothing")
    func testDeleteRequestedForDefaultCategoryIsIgnored() async throws {
        var initialState = CategoryManagementFeature.State()
        initialState.categories = [Self.foodCategory]

        let store = await TestStore(initialState: initialState) {
            CategoryManagementFeature()
        }

        await store.send(.deleteRequested(Self.foodCategory.id))
        // No state change — isDefault guard prevents deletion
    }
}
