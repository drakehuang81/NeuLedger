import Testing
import Foundation
import ComposableArchitecture
import Domain
@testable import Features

@Suite("TagManagementFeature Tests")
struct TagManagementFeatureTests {

    // MARK: - Helpers

    private static let tagA = Tag(
        id: UUID(uuidString: "20000000-0000-0000-0000-000000000001")!,
        name: "旅遊", color: "#FF9500"
    )
    private static let tagB = Tag(
        id: UUID(uuidString: "20000000-0000-0000-0000-000000000002")!,
        name: "工作", color: "#3478F6"
    )

    // MARK: - Load Tags

    @Test("task loads all tags")
    func testTaskLoadsTags() async throws {
        let tags = [Self.tagA, Self.tagB]

        let store = await TestStore(
            initialState: TagManagementFeature.State()
        ) {
            TagManagementFeature()
        } withDependencies: {
            $0.ledgerClient.listTags = { tags }
        }

        await store.send(.task) { $0.isLoading = true }

        await store.receive(\.tagsLoaded) {
            $0.isLoading = false
            $0.tags = tags
        }
    }

    // MARK: - Add Tag

    @Test("addButtonTapped presents add form")
    func testAddButtonTapped() async throws {
        let store = await TestStore(
            initialState: TagManagementFeature.State()
        ) {
            TagManagementFeature()
        }

        await store.send(.addButtonTapped) {
            $0.addEdit = AddEditTagFeature.State(mode: .add)
        }

        await store.send(\.addEdit.dismiss) {
            $0.addEdit = nil
        }
    }

    @Test("saveTapped with empty name sets nameError")
    func testAddTagEmptyNameValidation() async throws {
        let store = await TestStore(
            initialState: AddEditTagFeature.State(mode: .add)
        ) {
            AddEditTagFeature()
        }

        await store.send(.saveTapped) {
            $0.nameError = String(localized: "error_tag_name_empty")
        }
    }

    // MARK: - Edit Tag

    @Test("tagTapped presents edit form with existing data")
    func testTagTappedPresentsEditForm() async throws {
        let store = await TestStore(
            initialState: TagManagementFeature.State()
        ) {
            TagManagementFeature()
        }

        await store.send(.tagTapped(Self.tagA)) {
            $0.addEdit = AddEditTagFeature.State(mode: .edit(Self.tagA))
        }

        await store.send(\.addEdit.dismiss) {
            $0.addEdit = nil
        }
    }

    @Test("AddEditTagFeature nameChanged clears nameError")
    func testNameChangedClearsError() async throws {
        var initialState = AddEditTagFeature.State(mode: .add)
        initialState.nameError = String(localized: "error_tag_name_empty")

        let store = await TestStore(initialState: initialState) {
            AddEditTagFeature()
        }

        await store.send(.nameChanged("旅遊")) {
            $0.name = "旅遊"
            $0.nameError = nil
        }
    }

    // MARK: - Delete Tag

    @Test("deleteRequested shows confirmation alert")
    func testDeleteRequestedShowsAlert() async throws {
        let id = Self.tagA.id
        var initialState = TagManagementFeature.State()
        initialState.tags = [Self.tagA, Self.tagB]

        let store = await TestStore(initialState: initialState) {
            TagManagementFeature()
        }

        await store.send(.deleteRequested(id)) {
            $0.alert = AlertState {
                TextState(String(localized: "alert_delete_tag"))
            } actions: {
                ButtonState(role: .destructive, action: TagManagementFeature.Action.Alert.deleteConfirmed(id)) {
                    TextState(String(localized: "common_delete"))
                }
                ButtonState(role: .cancel) {
                    TextState(String(localized: "common_cancel"))
                }
            } message: {
                TextState(String(localized: "alert_delete_tag_message"))
            }
        }
    }

    @Test("deleteConfirmed calls tagClient.delete and reloads")
    func testDeleteConfirmed() async throws {
        let id = Self.tagA.id
        let deletedId: LockIsolated<Domain.Tag.ID?> = LockIsolated(nil)
        var initialState = TagManagementFeature.State()
        initialState.tags = [Self.tagA, Self.tagB]

        let store = await TestStore(initialState: initialState) {
            TagManagementFeature()
        } withDependencies: {
            $0.ledgerClient.deleteTag = { tagId in deletedId.setValue(tagId) }
            $0.ledgerClient.listTags = { [Self.tagB] }
        }

        await store.send(.deleteRequested(id)) {
            $0.alert = AlertState {
                TextState(String(localized: "alert_delete_tag"))
            } actions: {
                ButtonState(role: .destructive, action: TagManagementFeature.Action.Alert.deleteConfirmed(id)) {
                    TextState(String(localized: "common_delete"))
                }
                ButtonState(role: .cancel) {
                    TextState(String(localized: "common_cancel"))
                }
            } message: {
                TextState(String(localized: "alert_delete_tag_message"))
            }
        }

        await store.send(.alert(.presented(.deleteConfirmed(id)))) {
            $0.alert = nil
        }

        await store.receive(\.tagsLoaded) {
            $0.tags = [Self.tagB]
        }

        #expect(deletedId.value == id)
    }
}
