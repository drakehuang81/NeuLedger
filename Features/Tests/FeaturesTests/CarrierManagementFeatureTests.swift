import Testing
import Foundation
import ComposableArchitecture
import Domain
@testable import Features

@Suite("AddEditCarrierFeature Tests")
struct AddEditCarrierFeatureTests {

    private static let sampleCarrier = Carrier(
        id: UUID(uuidString: "30000000-0000-0000-0000-000000000001")!,
        name: "我的手機載具",
        type: .phoneBarcodeCarrier,
        barcode: "/ABC1234",
        createdAt: Date(timeIntervalSince1970: 0)
    )

    // MARK: - Validation

    @Test("barcodeChanged with valid phone carrier sets barcodeError to nil")
    func testValidPhoneBarcode() async {
        let store = await TestStore(
            initialState: AddEditCarrierFeature.State(mode: .add)
        ) { AddEditCarrierFeature() }

        await store.send(.barcodeChanged("/ABC1234")) {
            $0.barcode = "/ABC1234"
            $0.barcodeError = nil
        }
    }

    @Test("barcodeChanged with invalid phone carrier sets barcodeError")
    func testInvalidPhoneBarcode() async {
        let store = await TestStore(
            initialState: AddEditCarrierFeature.State(mode: .add)
        ) { AddEditCarrierFeature() }

        await store.send(.barcodeChanged("ABC1234")) {
            $0.barcode = "ABC1234"
            $0.barcodeError = String(localized: "carrier_barcode_error_phone")
        }
    }

    @Test("barcodeChanged with valid citizen cert sets barcodeError to nil")
    func testValidCitizenCertBarcode() async {
        var initial = AddEditCarrierFeature.State(mode: .add)
        initial.type = .citizenDigitalCertificate
        let store = await TestStore(initialState: initial) { AddEditCarrierFeature() }

        await store.send(.barcodeChanged("/PA1B2C3D4E5F6G7H8")) {
            $0.barcode = "/PA1B2C3D4E5F6G7H8"
            $0.barcodeError = nil
        }
    }

    @Test("barcodeChanged with invalid citizen cert sets barcodeError")
    func testInvalidCitizenCertBarcode() async {
        var initial = AddEditCarrierFeature.State(mode: .add)
        initial.type = .citizenDigitalCertificate
        let store = await TestStore(initialState: initial) { AddEditCarrierFeature() }

        await store.send(.barcodeChanged("/ABC")) {
            $0.barcode = "/ABC"
            $0.barcodeError = String(localized: "carrier_barcode_error_cert")
        }
    }

    @Test("typeChanged re-validates existing barcode")
    func testTypeChangedRevalidates() async {
        var initial = AddEditCarrierFeature.State(mode: .add)
        initial.barcode = "/ABC1234"
        let store = await TestStore(initialState: initial) { AddEditCarrierFeature() }

        // Switch to citizen cert — "/ABC1234" is invalid for that type
        await store.send(.typeChanged(.citizenDigitalCertificate)) {
            $0.type = .citizenDigitalCertificate
            $0.barcodeError = String(localized: "carrier_barcode_error_cert")
        }
    }

    @Test("saveTapped with empty barcode does not save")
    func testSaveTappedEmptyBarcode() async {
        let store = await TestStore(
            initialState: AddEditCarrierFeature.State(mode: .add)
        ) { AddEditCarrierFeature() }

        await store.send(.saveTapped)
        // No state change expected — canSave is false, action is no-op
    }

    @Test("saveTapped with valid barcode calls carrierClient.add")
    func testSaveTappedAdd() async {
        var initial = AddEditCarrierFeature.State(mode: .add)
        initial.name = "手機載具"
        initial.type = .phoneBarcodeCarrier
        initial.barcode = "/ABC1234"
        let addedCarrier: LockIsolated<Carrier?> = LockIsolated(nil)

        let store = await TestStore(initialState: initial) {
            AddEditCarrierFeature()
        } withDependencies: {
            $0.carrierClient.add = { carrier in addedCarrier.setValue(carrier) }
        }

        await store.send(.saveTapped) { $0.isSaving = true }
        await store.receive(\.savedSuccessfully) { $0.isSaving = false }
        await store.receive(\.delegate.saved)

        #expect(addedCarrier.value?.barcode == "/ABC1234")
        #expect(addedCarrier.value?.name == "手機載具")
    }

    @Test("saveTapped with empty name uses type default name")
    func testSaveTappedEmptyNameUsesDefault() async {
        var initial = AddEditCarrierFeature.State(mode: .add)
        initial.name = ""
        initial.barcode = "/ABC1234"
        let addedCarrier: LockIsolated<Carrier?> = LockIsolated(nil)

        let store = await TestStore(initialState: initial) {
            AddEditCarrierFeature()
        } withDependencies: {
            $0.carrierClient.add = { carrier in addedCarrier.setValue(carrier) }
        }

        await store.send(.saveTapped) { $0.isSaving = true }
        await store.receive(\.savedSuccessfully) { $0.isSaving = false }
        await store.receive(\.delegate.saved)

        #expect(addedCarrier.value?.name == String(localized: "carrier_type_phone_barcode"))
    }

    @Test("edit mode initialises with carrier data")
    @MainActor
    func testEditModeInitialisesWithData() async {
        let store = await TestStore(
            initialState: AddEditCarrierFeature.State(mode: .edit(Self.sampleCarrier))
        ) { AddEditCarrierFeature() }

        #expect(store.state.name == "我的手機載具")
        #expect(store.state.type == .phoneBarcodeCarrier)
        #expect(store.state.barcode == "/ABC1234")
    }

    @Test("saveTapped in edit mode calls carrierClient.update")
    func testSaveTappedUpdate() async {
        var initial = AddEditCarrierFeature.State(mode: .edit(Self.sampleCarrier))
        initial.name = "更新後名稱"
        let updatedCarrier: LockIsolated<Carrier?> = LockIsolated(nil)

        let store = await TestStore(initialState: initial) {
            AddEditCarrierFeature()
        } withDependencies: {
            $0.carrierClient.update = { carrier in updatedCarrier.setValue(carrier) }
        }

        await store.send(.saveTapped) { $0.isSaving = true }
        await store.receive(\.savedSuccessfully) { $0.isSaving = false }
        await store.receive(\.delegate.saved)

        #expect(updatedCarrier.value?.name == "更新後名稱")
        #expect(updatedCarrier.value?.id == Self.sampleCarrier.id)
    }
}

@Suite("CarrierManagementFeature Tests")
struct CarrierManagementFeatureTests {

    private static let carrierA = Carrier(
        id: UUID(uuidString: "30000000-0000-0000-0000-000000000001")!,
        name: "手機載具", type: .phoneBarcodeCarrier, barcode: "/ABC1234",
        createdAt: Date(timeIntervalSince1970: 0)
    )
    private static let carrierB = Carrier(
        id: UUID(uuidString: "30000000-0000-0000-0000-000000000002")!,
        name: "憑證", type: .citizenDigitalCertificate, barcode: "/PA1B2C3D4E5F6G7H8",
        createdAt: Date(timeIntervalSince1970: 1)
    )

    @Test("task loads all carriers")
    func testTaskLoadsCarriers() async {
        let carriers = [Self.carrierA, Self.carrierB]
        let store = await TestStore(
            initialState: CarrierManagementFeature.State()
        ) {
            CarrierManagementFeature()
        } withDependencies: {
            $0.carrierClient.fetchAll = { carriers }
        }

        await store.send(.task) { $0.isLoading = true }
        await store.receive(\.carriersLoaded) {
            $0.isLoading = false
            $0.carriers = carriers
        }
    }

    @Test("carrierRowTapped expands the tapped row")
    func testCarrierRowTappedExpands() async {
        var initial = CarrierManagementFeature.State()
        initial.carriers = [Self.carrierA, Self.carrierB]
        let store = await TestStore(initialState: initial) {
            CarrierManagementFeature()
        }

        await store.send(.carrierRowTapped(Self.carrierA.id)) {
            $0.expandedCarrierId = Self.carrierA.id
        }
    }

    @Test("carrierRowTapped same row collapses it")
    func testCarrierRowTappedCollapses() async {
        var initial = CarrierManagementFeature.State()
        initial.carriers = [Self.carrierA]
        initial.expandedCarrierId = Self.carrierA.id
        let store = await TestStore(initialState: initial) {
            CarrierManagementFeature()
        }

        await store.send(.carrierRowTapped(Self.carrierA.id)) {
            $0.expandedCarrierId = nil
        }
    }

    @Test("carrierRowTapped different row switches expansion")
    func testCarrierRowTappedSwitches() async {
        var initial = CarrierManagementFeature.State()
        initial.carriers = [Self.carrierA, Self.carrierB]
        initial.expandedCarrierId = Self.carrierA.id
        let store = await TestStore(initialState: initial) {
            CarrierManagementFeature()
        }

        await store.send(.carrierRowTapped(Self.carrierB.id)) {
            $0.expandedCarrierId = Self.carrierB.id
        }
    }

    @Test("addTapped presents add form")
    func testAddTapped() async {
        let store = await TestStore(
            initialState: CarrierManagementFeature.State()
        ) { CarrierManagementFeature() }

        await store.send(.addTapped) {
            $0.addEdit = AddEditCarrierFeature.State(mode: .add)
        }
    }

    @Test("deleteTapped clears widget when deleted carrier was the widget carrier")
    func testDeleteTappedClearsWidget() async {
        let deletedId: LockIsolated<Carrier.ID?> = LockIsolated(nil)
        let clearCarrierCalled: LockIsolated<Bool> = LockIsolated(false)

        var initial = CarrierManagementFeature.State()
        initial.carriers = [Self.carrierA, Self.carrierB]
        initial.expandedCarrierId = Self.carrierA.id  // carrierA is expanded

        let store = await TestStore(initialState: initial) {
            CarrierManagementFeature()
        } withDependencies: {
            $0.carrierClient.delete = { id in deletedId.setValue(id) }
            $0.carrierClient.fetchAll = { [Self.carrierB] }
            // carrierA is the current widget carrier
            $0.userSettingsClient.string = { _ in Self.carrierA.id.uuidString }
            $0.userSettingsClient.setString = { _, _ in }
            $0.widgetSyncClient.clearCarrier = { clearCarrierCalled.setValue(true) }
        }

        await store.send(.deleteTapped(Self.carrierA.id)) {
            $0.expandedCarrierId = nil  // expanded row is collapsed immediately
        }
        await store.receive(\.carriersLoaded) {
            $0.carriers = [Self.carrierB]
        }

        #expect(deletedId.value == Self.carrierA.id)
        #expect(clearCarrierCalled.value == true)
    }

    @Test("deleteTapped with expanded row collapses and removes carrier (non-widget carrier)")
    func testDeleteTapped() async {
        let deletedId: LockIsolated<Carrier.ID?> = LockIsolated(nil)
        let clearCarrierCalled: LockIsolated<Bool> = LockIsolated(false)

        var initial = CarrierManagementFeature.State()
        initial.carriers = [Self.carrierA, Self.carrierB]
        initial.expandedCarrierId = Self.carrierA.id  // carrierA is expanded

        let store = await TestStore(initialState: initial) {
            CarrierManagementFeature()
        } withDependencies: {
            $0.carrierClient.delete = { id in deletedId.setValue(id) }
            $0.carrierClient.fetchAll = { [Self.carrierB] }
            // carrierB is the widget carrier, not carrierA
            $0.userSettingsClient.string = { _ in Self.carrierB.id.uuidString }
            $0.widgetSyncClient.clearCarrier = { clearCarrierCalled.setValue(true) }
        }

        await store.send(.deleteTapped(Self.carrierA.id)) {
            $0.expandedCarrierId = nil  // expanded row is collapsed immediately
        }
        await store.receive(\.carriersLoaded) {
            $0.carriers = [Self.carrierB]
        }

        #expect(deletedId.value == Self.carrierA.id)
        // Widget carrier was NOT deleted, so clearCarrier must NOT be called
        #expect(clearCarrierCalled.value == false)
    }

    @Test("saved delegate reloads carriers and syncs widget when edited carrier is widget carrier")
    func testEditTappedSyncsWidget() async {
        let syncBarcode: LockIsolated<String?> = LockIsolated(nil)
        var initial = CarrierManagementFeature.State()
        initial.addEdit = AddEditCarrierFeature.State(mode: .edit(Self.carrierA))

        let store = await TestStore(initialState: initial) {
            CarrierManagementFeature()
        } withDependencies: {
            $0.carrierClient.fetchAll = { [Self.carrierA, Self.carrierB] }
            // carrierA is the current widget carrier
            $0.userSettingsClient.string = { _ in Self.carrierA.id.uuidString }
            $0.widgetSyncClient.syncCarrier = { barcode, _, _ in syncBarcode.setValue(barcode) }
        }

        await store.send(.addEdit(.presented(.delegate(.saved)))) {
            $0.addEdit = nil
        }
        await store.receive(\.carriersLoaded) {
            $0.carriers = [Self.carrierA, Self.carrierB]
        }

        #expect(syncBarcode.value == Self.carrierA.barcode)
    }

    @Test("saved delegate reloads carriers")
    func testSavedDelegateReloads() async {
        var initial = CarrierManagementFeature.State()
        initial.addEdit = AddEditCarrierFeature.State(mode: .add)
        let store = await TestStore(initialState: initial) {
            CarrierManagementFeature()
        } withDependencies: {
            $0.carrierClient.fetchAll = { [Self.carrierA] }
            // No widget carrier set yet — empty string triggers auto-assign path
            $0.userSettingsClient.string = { _ in "" }
            $0.userSettingsClient.setString = { _, _ in }
            $0.widgetSyncClient.syncCarrier = { _, _, _ in }
        }

        await store.send(.addEdit(.presented(.delegate(.saved)))) {
            $0.addEdit = nil
        }
        await store.receive(\.carriersLoaded) {
            $0.carriers = [Self.carrierA]
        }
    }

    @Test("addFirstCarrier auto-sets as widget carrier when no widget carrier exists")
    func testAddFirstCarrierAutoSetsWidget() async {
        let savedId: LockIsolated<String?> = LockIsolated(nil)
        let syncedBarcode: LockIsolated<String?> = LockIsolated(nil)
        let syncedType: LockIsolated<String?> = LockIsolated(nil)
        let syncedName: LockIsolated<String?> = LockIsolated(nil)

        var initial = CarrierManagementFeature.State()
        initial.addEdit = AddEditCarrierFeature.State(mode: .add)

        let store = await TestStore(initialState: initial) {
            CarrierManagementFeature()
        } withDependencies: {
            // carrierA is returned as the first-ever carrier
            $0.carrierClient.fetchAll = { [Self.carrierA] }
            // No widget carrier set yet
            $0.userSettingsClient.string = { _ in "" }
            $0.userSettingsClient.setString = { value, _ in savedId.setValue(value) }
            $0.widgetSyncClient.syncCarrier = { barcode, type, name in
                syncedBarcode.setValue(barcode)
                syncedType.setValue(type)
                syncedName.setValue(name)
            }
        }

        await store.send(.addEdit(.presented(.delegate(.saved)))) {
            $0.addEdit = nil
        }
        await store.receive(\.carriersLoaded) {
            $0.carriers = [Self.carrierA]
        }

        #expect(savedId.value == Self.carrierA.id.uuidString)
        #expect(syncedBarcode.value == Self.carrierA.barcode)
        #expect(syncedType.value == Self.carrierA.type.rawValue)
        #expect(syncedName.value == Self.carrierA.name)
    }
}
