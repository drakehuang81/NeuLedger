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

    @Test("saveTapped with valid barcode calls carrierClient.create")
    func testSaveTappedAdd() async {
        var initial = AddEditCarrierFeature.State(mode: .add)
        initial.name = "手機載具"
        initial.type = .phoneBarcodeCarrier
        initial.barcode = "/ABC1234"
        let addedCarrier: LockIsolated<Carrier?> = LockIsolated(nil)

        let store = await TestStore(initialState: initial) {
            AddEditCarrierFeature()
        } withDependencies: {
            $0.carrierClient.create = { carrier in addedCarrier.setValue(carrier) }
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
            $0.carrierClient.create = { carrier in addedCarrier.setValue(carrier) }
        }

        await store.send(.saveTapped) { $0.isSaving = true }
        await store.receive(\.savedSuccessfully) { $0.isSaving = false }
        await store.receive(\.delegate.saved)

        #expect(addedCarrier.value?.name == String(localized: "carrier_type_phone_barcode"))
    }

    @Test("edit mode initialises with carrier data")
    @MainActor
    func testEditModeInitialisesWithData() async {
        let store = TestStore(
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
            $0.carrierClient.listAll = { carriers }
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

        await store.send(\.addEdit.dismiss) {
            $0.addEdit = nil
        }
    }

    @Test("deleteTapped re-points widget when deleted carrier was the widget carrier")
    func testDeleteTappedClearsWidget() async {
        let deletedId: LockIsolated<Carrier.ID?> = LockIsolated(nil)
        let setActiveId: LockIsolated<Carrier.ID?> = LockIsolated(nil)

        var initial = CarrierManagementFeature.State()
        initial.carriers = [Self.carrierA, Self.carrierB]
        initial.expandedCarrierId = Self.carrierA.id  // carrierA is expanded

        let store = await TestStore(initialState: initial) {
            CarrierManagementFeature()
        } withDependencies: {
            $0.carrierClient.delete = { id in deletedId.setValue(id) }
            $0.carrierClient.listAll = { [Self.carrierB] }
            // carrierA is the current active widget carrier
            $0.carrierClient.activeForWidget = { Self.carrierA.id }
            $0.carrierClient.setActiveForWidget = { id in setActiveId.setValue(id) }
        }

        // deleteTapped now shows a confirmation alert
        await store.send(.deleteTapped(Self.carrierA.id)) {
            $0.alert = AlertState {
                TextState(String(localized: "alert_delete_carrier"))
            } actions: {
                ButtonState(role: .destructive, action: .deleteConfirmed(Self.carrierA.id)) {
                    TextState(String(localized: "common_delete"))
                }
                ButtonState(role: .cancel) {
                    TextState(String(localized: "common_cancel"))
                }
            } message: {
                TextState(String(format: String(localized: "alert_delete_carrier_message"), Self.carrierA.name))
            }
        }
        // Confirm deletion — this triggers the actual delete effect
        await store.send(.alert(.presented(.deleteConfirmed(Self.carrierA.id)))) {
            $0.alert = nil
            $0.expandedCarrierId = nil  // expanded row is collapsed on confirm
        }
        await store.receive(\.delegate.carriersChanged)
        await store.receive(\.carriersLoaded) {
            $0.carriers = [Self.carrierB]
        }

        #expect(deletedId.value == Self.carrierA.id)
        // Deleted carrier was the active widget carrier → re-point to first remaining
        #expect(setActiveId.value == Self.carrierB.id)
    }

    @Test("deleteTapped with expanded row collapses and removes carrier (non-widget carrier)")
    func testDeleteTapped() async {
        let deletedId: LockIsolated<Carrier.ID?> = LockIsolated(nil)
        let setActiveCalled: LockIsolated<Bool> = LockIsolated(false)

        var initial = CarrierManagementFeature.State()
        initial.carriers = [Self.carrierA, Self.carrierB]
        initial.expandedCarrierId = Self.carrierA.id  // carrierA is expanded

        let store = await TestStore(initialState: initial) {
            CarrierManagementFeature()
        } withDependencies: {
            $0.carrierClient.delete = { id in deletedId.setValue(id) }
            $0.carrierClient.listAll = { [Self.carrierB] }
            // carrierB is the active widget carrier, not carrierA
            $0.carrierClient.activeForWidget = { Self.carrierB.id }
            $0.carrierClient.setActiveForWidget = { _ in setActiveCalled.setValue(true) }
        }

        // deleteTapped now shows a confirmation alert
        await store.send(.deleteTapped(Self.carrierA.id)) {
            $0.alert = AlertState {
                TextState(String(localized: "alert_delete_carrier"))
            } actions: {
                ButtonState(role: .destructive, action: .deleteConfirmed(Self.carrierA.id)) {
                    TextState(String(localized: "common_delete"))
                }
                ButtonState(role: .cancel) {
                    TextState(String(localized: "common_cancel"))
                }
            } message: {
                TextState(String(format: String(localized: "alert_delete_carrier_message"), Self.carrierA.name))
            }
        }
        // Confirm deletion — this triggers the actual delete effect
        await store.send(.alert(.presented(.deleteConfirmed(Self.carrierA.id)))) {
            $0.alert = nil
            $0.expandedCarrierId = nil  // expanded row is collapsed on confirm
        }
        await store.receive(\.delegate.carriersChanged)
        await store.receive(\.carriersLoaded) {
            $0.carriers = [Self.carrierB]
        }

        #expect(deletedId.value == Self.carrierA.id)
        // Active widget carrier was NOT deleted, so it must NOT be re-pointed
        #expect(setActiveCalled.value == false)
    }

    @Test("saved delegate reloads carriers without re-assigning when widget carrier already set")
    func testEditTappedSyncsWidget() async {
        let listAllCalled: LockIsolated<Bool> = LockIsolated(false)
        let setActiveCalled: LockIsolated<Bool> = LockIsolated(false)
        var initial = CarrierManagementFeature.State()
        initial.addEdit = AddEditCarrierFeature.State(mode: .edit(Self.carrierA))

        let store = await TestStore(initialState: initial) {
            CarrierManagementFeature()
        } withDependencies: {
            $0.carrierClient.listAll = {
                listAllCalled.setValue(true)
                return [Self.carrierA, Self.carrierB]
            }
            // carrierA is already the active widget carrier — no auto-assign expected.
            // The widget sync for the edited carrier happens inside carrierClient.update.
            $0.carrierClient.activeForWidget = { Self.carrierA.id }
            $0.carrierClient.setActiveForWidget = { _ in setActiveCalled.setValue(true) }
        }

        await store.send(.addEdit(.presented(.delegate(.saved)))) {
            $0.addEdit = nil
        }
        await store.receive(\.delegate.carriersChanged)
        await store.receive(\.carriersLoaded) {
            $0.carriers = [Self.carrierA, Self.carrierB]
        }

        #expect(listAllCalled.value == true)
        #expect(setActiveCalled.value == false)
    }

    @Test("saved delegate reloads carriers")
    func testSavedDelegateReloads() async {
        var initial = CarrierManagementFeature.State()
        initial.addEdit = AddEditCarrierFeature.State(mode: .add)
        let store = await TestStore(initialState: initial) {
            CarrierManagementFeature()
        } withDependencies: {
            $0.carrierClient.listAll = { [Self.carrierA] }
            // No widget carrier set yet — nil triggers auto-assign path
            $0.carrierClient.activeForWidget = { nil }
            $0.carrierClient.setActiveForWidget = { _ in }
        }

        await store.send(.addEdit(.presented(.delegate(.saved)))) {
            $0.addEdit = nil
        }
        await store.receive(\.delegate.carriersChanged)
        await store.receive(\.carriersLoaded) {
            $0.carriers = [Self.carrierA]
        }
    }

    @Test("addFirstCarrier auto-sets as widget carrier when no widget carrier exists")
    func testAddFirstCarrierAutoSetsWidget() async {
        let setActiveId: LockIsolated<Carrier.ID?> = LockIsolated(nil)

        var initial = CarrierManagementFeature.State()
        initial.addEdit = AddEditCarrierFeature.State(mode: .add)

        let store = await TestStore(initialState: initial) {
            CarrierManagementFeature()
        } withDependencies: {
            // carrierA is returned as the first-ever carrier
            $0.carrierClient.listAll = { [Self.carrierA] }
            // No widget carrier set yet → auto-assign path
            $0.carrierClient.activeForWidget = { nil }
            $0.carrierClient.setActiveForWidget = { id in setActiveId.setValue(id) }
        }

        await store.send(.addEdit(.presented(.delegate(.saved)))) {
            $0.addEdit = nil
        }
        await store.receive(\.delegate.carriersChanged)
        await store.receive(\.carriersLoaded) {
            $0.carriers = [Self.carrierA]
        }

        // First-ever carrier becomes the active widget carrier; the actual App Group
        // write + widget reload is performed inside carrierClient.setActiveForWidget.
        #expect(setActiveId.value == Self.carrierA.id)
    }

    @Test("task loads carriers via carrierClient.listAll")
    func testTaskTriggersSyncAllCarriers() async {
        let sample = Carrier(
            id: UUID(uuidString: "40000000-0000-0000-0000-000000000001")!,
            name: "Phone Carrier",
            type: .phoneBarcodeCarrier,
            barcode: "/ABC1234",
            createdAt: Date(timeIntervalSince1970: 0)
        )
        let listAllCalled = LockIsolated<Bool>(false)
        let store = await TestStore(
            initialState: CarrierManagementFeature.State()
        ) {
            CarrierManagementFeature()
        } withDependencies: {
            // Widget reload on read is no longer a Feature concern — listAll is the
            // only carrierClient call the task makes (mutations sync inside the Client).
            $0.carrierClient.listAll = {
                listAllCalled.setValue(true)
                return [sample]
            }
        }

        await store.send(.task) {
            $0.isLoading = true
        }
        await store.receive(\.carriersLoaded) {
            $0.isLoading = false
            $0.carriers = [sample]
        }
        #expect(listAllCalled.value == true)
    }

    @Test("deleteTapped removes carrier via carrierClient.delete")
    func testDeleteTappedTriggersSyncAllCarriers() async {
        let remaining = Carrier(
            id: UUID(uuidString: "40000000-0000-0000-0000-000000000002")!,
            name: "Cert Carrier",
            type: .citizenDigitalCertificate,
            barcode: "/PA1B2C3D4E5F6G7H8",
            createdAt: Date(timeIntervalSince1970: 0)
        )
        let deletedId = UUID(uuidString: "40000000-0000-0000-0000-000000000003")!
        let deletedSpy = LockIsolated<Carrier.ID?>(nil)
        let store = await TestStore(
            initialState: CarrierManagementFeature.State()
        ) {
            CarrierManagementFeature()
        } withDependencies: {
            // The widget reload after delete is now internal to carrierClient.delete.
            $0.carrierClient.delete = { id in deletedSpy.setValue(id) }
            $0.carrierClient.listAll = { [remaining] }
            $0.carrierClient.activeForWidget = { nil }
        }

        // deleteTapped now shows a confirmation alert
        await store.send(.deleteTapped(deletedId)) {
            $0.alert = AlertState {
                TextState(String(localized: "alert_delete_carrier"))
            } actions: {
                ButtonState(role: .destructive, action: .deleteConfirmed(deletedId)) {
                    TextState(String(localized: "common_delete"))
                }
                ButtonState(role: .cancel) {
                    TextState(String(localized: "common_cancel"))
                }
            } message: {
                TextState(String(format: String(localized: "alert_delete_carrier_message"), ""))
            }
        }
        // Confirm deletion
        await store.send(.alert(.presented(.deleteConfirmed(deletedId)))) {
            $0.alert = nil
        }
        await store.receive(\.delegate.carriersChanged)
        await store.receive(\.carriersLoaded) {
            $0.carriers = [remaining]
        }
        #expect(deletedSpy.value == deletedId)
    }

    @Test("save delegate reloads carriers via carrierClient.listAll")
    func testSaveDelegateTriggersSyncAllCarriers() async {
        let saved = Carrier(
            id: UUID(uuidString: "40000000-0000-0000-0000-000000000004")!,
            name: "New",
            type: .phoneBarcodeCarrier,
            barcode: "/ZZZ9999",
            createdAt: Date(timeIntervalSince1970: 0)
        )
        let listAllCalled = LockIsolated<Bool>(false)
        var initial = CarrierManagementFeature.State()
        initial.addEdit = AddEditCarrierFeature.State(mode: .add)
        let store = await TestStore(initialState: initial) {
            CarrierManagementFeature()
        } withDependencies: {
            // The widget reload after create is internal to carrierClient.create
            // (invoked by AddEditCarrierFeature); the parent only reloads + auto-assigns.
            $0.carrierClient.listAll = {
                listAllCalled.setValue(true)
                return [saved]
            }
            $0.carrierClient.activeForWidget = { nil }
            $0.carrierClient.setActiveForWidget = { _ in }
        }

        await store.send(\.addEdit.presented.delegate.saved) {
            $0.addEdit = nil
        }
        await store.receive(\.delegate.carriersChanged)
        await store.receive(\.carriersLoaded) {
            $0.carriers = [saved]
        }
        #expect(listAllCalled.value == true)
    }
}
