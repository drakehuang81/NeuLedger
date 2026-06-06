import Testing
import Foundation
import ComposableArchitecture
@testable import Features
import Domain

@Suite("AddEditAccountFeature Tests")
struct AddEditAccountFeatureTests {

    // MARK: - Shared fixtures

    private static let sampleAccount = Account(
        id: "acc-edit-1",
        name: "玉山銀行",
        type: .bank,
        icon: "building.columns",
        color: "#0A84FF",
        sortOrder: 2,
        isArchived: false,
        createdAt: Date(timeIntervalSinceReferenceDate: 770_000_000)
    )

    // MARK: - State init defaults (audit A1)

    @Test("add mode defaults follow AccountType.cash SSOT (defaultIcon/defaultColor)")
    func testAddModeDefaultsFollowAccountTypeSSOT() async {
        let state = AddEditAccountFeature.State(mode: .add)
        #expect(state.type == .cash)
        #expect(state.icon == state.type.defaultIcon)
        #expect(state.colorHex == state.type.defaultColor)
    }

    @Test("edit mode init copies the account's own icon and color")
    func testEditModeCopiesAccountValues() async {
        let account = Account(
            id: "acc-1", name: "玉山銀行", type: .bank,
            icon: "building.columns", color: "#0A84FF",
            sortOrder: 0, isArchived: false, createdAt: Date()
        )
        let state = AddEditAccountFeature.State(mode: .edit(account))
        #expect(state.icon == "building.columns")
        #expect(state.colorHex == "#0A84FF")
    }

    // MARK: - Save .add success

    @Test("save .add calls createAccount with correct fields and emits delegate.saved")
    func testSaveAddSuccess() async {
        let created = LockIsolated<Account?>(nil)

        let store = await TestStore(
            initialState: AddEditAccountFeature.State(mode: .add)
        ) {
            AddEditAccountFeature()
        } withDependencies: {
            $0.ledgerClient.createAccount = { created.setValue($0) }
            $0.dismiss = DismissEffect {}
        }

        await store.send(.nameChanged("現金")) { $0.name = "現金" }
        await store.send(.typeChanged(.eWallet)) { $0.type = .eWallet }
        await store.send(.iconChanged("wallet.bifold")) { $0.icon = "wallet.bifold" }
        await store.send(.colorHexChanged("#34C759")) { $0.colorHex = "#34C759" }
        await store.send(.saveTapped)
        await store.receive(\.savedSuccessfully)
        await store.receive(\.delegate.saved)

        #expect(created.value?.name == "現金")
        #expect(created.value?.type == .eWallet)
        #expect(created.value?.icon == "wallet.bifold")
        #expect(created.value?.color == "#34C759")
    }

    // MARK: - Save .edit success

    @Test("save .edit calls updateAccount preserving id and updating fields")
    func testSaveEditSuccess() async {
        let updated = LockIsolated<Account?>(nil)
        let original = Self.sampleAccount

        let store = await TestStore(
            initialState: AddEditAccountFeature.State(mode: .edit(original))
        ) {
            AddEditAccountFeature()
        } withDependencies: {
            $0.ledgerClient.updateAccount = { updated.setValue($0) }
            $0.dismiss = DismissEffect {}
        }

        await store.send(.nameChanged("台新銀行")) { $0.name = "台新銀行" }
        await store.send(.iconChanged("creditcard")) { $0.icon = "creditcard" }
        await store.send(.colorHexChanged("#FF2D55")) { $0.colorHex = "#FF2D55" }
        await store.send(.saveTapped)
        await store.receive(\.savedSuccessfully)
        await store.receive(\.delegate.saved)

        #expect(updated.value?.id == original.id)
        #expect(updated.value?.name == "台新銀行")
        #expect(updated.value?.icon == "creditcard")
        #expect(updated.value?.color == "#FF2D55")
        #expect(updated.value?.sortOrder == original.sortOrder)
        #expect(updated.value?.isArchived == original.isArchived)
    }

    // MARK: - Name validation failure (empty)

    @Test("saveTapped with empty name sets nameError and does NOT call createAccount")
    func testSaveEmptyNameSetsError() async {
        let created = LockIsolated<Account?>(nil)

        let store = await TestStore(
            initialState: AddEditAccountFeature.State(mode: .add)
        ) {
            AddEditAccountFeature()
        } withDependencies: {
            $0.ledgerClient.createAccount = { created.setValue($0) }
        }

        // name is empty by default
        await store.send(.saveTapped) {
            $0.nameError = String(localized: "error_account_name_empty")
        }

        #expect(created.value == nil)
    }

    // MARK: - Name validation failure (duplicate)

    @Test("saveTapped with duplicate name sets nameError and does NOT call createAccount")
    func testSaveDuplicateNameSetsError() async {
        let created = LockIsolated<Account?>(nil)

        var initialState = AddEditAccountFeature.State(mode: .add, existingNames: ["現金"])
        initialState.name = "現金"

        let store = await TestStore(initialState: initialState) {
            AddEditAccountFeature()
        } withDependencies: {
            $0.ledgerClient.createAccount = { created.setValue($0) }
        }

        await store.send(.saveTapped) {
            $0.nameError = String(localized: "error_account_name_taken")
        }

        #expect(created.value == nil)
    }

    // MARK: - Validation error clears on nameChanged

    @Test("nameChanged clears nameError")
    func testNameChangedClearsError() async {
        var initialState = AddEditAccountFeature.State(mode: .add)
        initialState.nameError = "stale error"

        let store = await TestStore(initialState: initialState) {
            AddEditAccountFeature()
        }

        await store.send(.nameChanged("新名稱")) {
            $0.name = "新名稱"
            $0.nameError = nil
        }
    }

    // MARK: - cancelTapped

    @Test("cancelTapped emits delegate.dismissed")
    func testCancelTapped() async {
        let store = await TestStore(
            initialState: AddEditAccountFeature.State(mode: .add)
        ) {
            AddEditAccountFeature()
        } withDependencies: {
            $0.dismiss = DismissEffect {}
        }

        await store.send(.cancelTapped)
        await store.receive(\.delegate.dismissed)
    }

    // MARK: - Setters

    @Test("typeChanged updates state.type")
    func testTypeChanged() async {
        let store = await TestStore(
            initialState: AddEditAccountFeature.State(mode: .add)
        ) {
            AddEditAccountFeature()
        }

        await store.send(.typeChanged(.creditCard)) {
            $0.type = .creditCard
        }
    }

    @Test("iconChanged updates state.icon")
    func testIconChanged() async {
        let store = await TestStore(
            initialState: AddEditAccountFeature.State(mode: .add)
        ) {
            AddEditAccountFeature()
        }

        await store.send(.iconChanged("wallet.bifold")) {
            $0.icon = "wallet.bifold"
        }
    }

    @Test("colorHexChanged updates state.colorHex")
    func testColorHexChanged() async {
        let store = await TestStore(
            initialState: AddEditAccountFeature.State(mode: .add)
        ) {
            AddEditAccountFeature()
        }

        await store.send(.colorHexChanged("#5E5CE6")) {
            $0.colorHex = "#5E5CE6"
        }
    }
}
