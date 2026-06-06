import Testing
import Foundation
import ComposableArchitecture
@testable import Features
import Domain
@testable import Common

@Suite("AddEditTagFeature Tests")
struct AddEditTagFeatureTests {

    // MARK: - Shared fixtures

    private static let sampleTag = Domain.Tag(
        id: UUID(uuidString: "20000000-0000-0000-0000-000000000010")!,
        name: "旅遊",
        color: "#FF9500"
    )

    private static let tagWithNilColor = Domain.Tag(
        id: UUID(uuidString: "20000000-0000-0000-0000-000000000011")!,
        name: "工作",
        color: nil
    )

    // MARK: - State init defaults

    @Test("add mode defaults: name empty, colorHex == DesignConstants.defaultTagColorHex")
    func testAddModeDefaults() async {
        let state = AddEditTagFeature.State(mode: .add)
        #expect(state.name == "")
        #expect(state.colorHex == DesignConstants.defaultTagColorHex)
        #expect(state.nameError == nil)
    }

    @Test("edit mode copies tag's name and color")
    func testEditModeCopiesValues() async {
        let tag = Self.sampleTag
        let state = AddEditTagFeature.State(mode: .edit(tag))
        #expect(state.name == tag.name)
        #expect(state.colorHex == tag.color)
    }

    @Test("edit mode with nil color falls back to defaultTagColorHex")
    func testEditModeNilColorFallback() async {
        let tag = Self.tagWithNilColor
        let state = AddEditTagFeature.State(mode: .edit(tag))
        #expect(state.colorHex == DesignConstants.defaultTagColorHex)
    }

    // MARK: - Save .add success

    @Test("save .add calls ledger.createTag with correct fields and emits delegate.saved")
    func testSaveAddSuccess() async {
        let created = LockIsolated<Domain.Tag?>(nil)

        let store = await TestStore(
            initialState: AddEditTagFeature.State(mode: .add)
        ) {
            AddEditTagFeature()
        } withDependencies: {
            $0.ledgerClient.createTag = { created.setValue($0) }
            $0.dismiss = DismissEffect {}
        }

        await store.send(.nameChanged("食物")) { $0.name = "食物" }
        await store.send(.saveTapped)
        await store.receive(\.savedSuccessfully)
        await store.receive(\.delegate.saved)

        #expect(created.value?.name == "食物")
        #expect(created.value?.color == DesignConstants.defaultTagColorHex)
    }

    // MARK: - colorHex 端到端

    @Test("colorHexChanged then save — spy confirms Tag.color equals new hex")
    func testColorHexEndToEnd() async {
        let created = LockIsolated<Domain.Tag?>(nil)

        let store = await TestStore(
            initialState: AddEditTagFeature.State(mode: .add)
        ) {
            AddEditTagFeature()
        } withDependencies: {
            $0.ledgerClient.createTag = { created.setValue($0) }
            $0.dismiss = DismissEffect {}
        }

        await store.send(.nameChanged("購物")) { $0.name = "購物" }
        await store.send(.colorHexChanged("#FF2D55")) { $0.colorHex = "#FF2D55" }
        await store.send(.saveTapped)
        await store.receive(\.savedSuccessfully)
        await store.receive(\.delegate.saved)

        #expect(created.value?.color == "#FF2D55")
        #expect(created.value?.name == "購物")
    }

    // MARK: - Save .edit success

    @Test("save .edit calls ledger.updateTag preserving id and updating fields")
    func testSaveEditSuccess() async {
        let updated = LockIsolated<Domain.Tag?>(nil)
        let original = Self.sampleTag

        let store = await TestStore(
            initialState: AddEditTagFeature.State(mode: .edit(original))
        ) {
            AddEditTagFeature()
        } withDependencies: {
            $0.ledgerClient.updateTag = { updated.setValue($0) }
            $0.dismiss = DismissEffect {}
        }

        await store.send(.nameChanged("出差")) { $0.name = "出差" }
        await store.send(.colorHexChanged("#AF52DE")) { $0.colorHex = "#AF52DE" }
        await store.send(.saveTapped)
        await store.receive(\.savedSuccessfully)
        await store.receive(\.delegate.saved)

        #expect(updated.value?.id == original.id)
        #expect(updated.value?.name == "出差")
        #expect(updated.value?.color == "#AF52DE")
    }

    // MARK: - Name validation failure

    @Test("saveTapped with empty name sets nameError and does NOT call createTag")
    func testSaveEmptyNameSetsError() async {
        let created = LockIsolated<Domain.Tag?>(nil)

        let store = await TestStore(
            initialState: AddEditTagFeature.State(mode: .add)
        ) {
            AddEditTagFeature()
        } withDependencies: {
            $0.ledgerClient.createTag = { created.setValue($0) }
        }

        // name is empty by default
        await store.send(.saveTapped) {
            $0.nameError = String(localized: "error_tag_name_empty")
        }

        #expect(created.value == nil)
    }

    @Test("saveTapped with whitespace-only name sets nameError and does NOT call createTag")
    func testSaveWhitespaceNameSetsError() async {
        let created = LockIsolated<Domain.Tag?>(nil)

        let store = await TestStore(
            initialState: AddEditTagFeature.State(mode: .add)
        ) {
            AddEditTagFeature()
        } withDependencies: {
            $0.ledgerClient.createTag = { created.setValue($0) }
        }

        await store.send(.nameChanged("   ")) { $0.name = "   " }
        await store.send(.saveTapped) {
            $0.nameError = String(localized: "error_tag_name_empty")
        }

        #expect(created.value == nil)
    }

    // MARK: - cancelTapped

    @Test("cancelTapped emits delegate.dismissed")
    func testCancelTapped() async {
        let store = await TestStore(
            initialState: AddEditTagFeature.State(mode: .add)
        ) {
            AddEditTagFeature()
        } withDependencies: {
            $0.dismiss = DismissEffect {}
        }

        await store.send(.cancelTapped)
        await store.receive(\.delegate.dismissed)
    }

    // MARK: - Setters

    @Test("nameChanged updates state.name and clears nameError")
    func testNameChangedUpdatesAndClearsError() async {
        var initialState = AddEditTagFeature.State(mode: .add)
        initialState.nameError = String(localized: "error_tag_name_empty")

        let store = await TestStore(initialState: initialState) {
            AddEditTagFeature()
        }

        await store.send(.nameChanged("工作")) {
            $0.name = "工作"
            $0.nameError = nil
        }
    }

    @Test("colorHexChanged updates state.colorHex")
    func testColorHexChanged() async {
        let store = await TestStore(
            initialState: AddEditTagFeature.State(mode: .add)
        ) {
            AddEditTagFeature()
        }

        await store.send(.colorHexChanged("#5E5CE6")) {
            $0.colorHex = "#5E5CE6"
        }
    }

    // MARK: - savedSuccessfully → delegate.saved

    @Test("savedSuccessfully emits delegate.saved then dismiss")
    func testSavedSuccessfullyEmitsDelegateSaved() async {
        let store = await TestStore(
            initialState: AddEditTagFeature.State(mode: .add)
        ) {
            AddEditTagFeature()
        } withDependencies: {
            $0.dismiss = DismissEffect {}
        }

        await store.send(.savedSuccessfully)
        await store.receive(\.delegate.saved)
    }
}
