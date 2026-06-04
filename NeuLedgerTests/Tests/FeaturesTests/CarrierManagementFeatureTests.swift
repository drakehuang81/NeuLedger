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
            $0.carrierClient.fetchAll = { carriers }
            $0.widgetSyncAdapter.syncAllCarriers = { _ in }
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
            $0.userSettingsAdapter.string = { _ in Self.carrierA.id.uuidString }
            $0.userSettingsAdapter.setString = { _, _ in }
            $0.widgetSyncAdapter.clearCarrier = { clearCarrierCalled.setValue(true) }
            $0.widgetSyncAdapter.syncAllCarriers = { _ in }
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
            $0.userSettingsAdapter.string = { _ in Self.carrierB.id.uuidString }
            $0.widgetSyncAdapter.clearCarrier = { clearCarrierCalled.setValue(true) }
            $0.widgetSyncAdapter.syncAllCarriers = { _ in }
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
            $0.userSettingsAdapter.string = { _ in Self.carrierA.id.uuidString }
            $0.widgetSyncAdapter.syncCarrier = { barcode, _, _ in syncBarcode.setValue(barcode) }
            $0.widgetSyncAdapter.syncAllCarriers = { _ in }
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
            $0.userSettingsAdapter.string = { _ in "" }
            $0.userSettingsAdapter.setString = { _, _ in }
            $0.widgetSyncAdapter.syncCarrier = { _, _, _ in }
            $0.widgetSyncAdapter.syncAllCarriers = { _ in }
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
            $0.userSettingsAdapter.string = { _ in "" }
            $0.userSettingsAdapter.setString = { value, _ in savedId.setValue(value) }
            $0.widgetSyncAdapter.syncCarrier = { barcode, type, name in
                syncedBarcode.setValue(barcode)
                syncedType.setValue(type)
                syncedName.setValue(name)
            }
            $0.widgetSyncAdapter.syncAllCarriers = { _ in }
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

    @Test("task triggers syncAllCarriers with fetched list")
    func testTaskTriggersSyncAllCarriers() async {
        let sample = Carrier(
            id: UUID(uuidString: "40000000-0000-0000-0000-000000000001")!,
            name: "Phone Carrier",
            type: .phoneBarcodeCarrier,
            barcode: "/ABC1234",
            createdAt: Date(timeIntervalSince1970: 0)
        )
        let syncedCarriers = LockIsolated<[Carrier]?>(nil)
        let store = await TestStore(
            initialState: CarrierManagementFeature.State()
        ) {
            CarrierManagementFeature()
        } withDependencies: {
            $0.carrierClient.fetchAll = { [sample] }
            $0.widgetSyncAdapter.syncAllCarriers = { carriers in
                syncedCarriers.setValue(carriers)
            }
        }

        await store.send(.task) {
            $0.isLoading = true
        }
        await store.receive(\.carriersLoaded) {
            $0.isLoading = false
            $0.carriers = [sample]
        }
        #expect(syncedCarriers.value == [sample])
    }

    @Test("deleteTapped triggers syncAllCarriers with refreshed list")
    func testDeleteTappedTriggersSyncAllCarriers() async {
        let remaining = Carrier(
            id: UUID(uuidString: "40000000-0000-0000-0000-000000000002")!,
            name: "Cert Carrier",
            type: .citizenDigitalCertificate,
            barcode: "/PA1B2C3D4E5F6G7H8",
            createdAt: Date(timeIntervalSince1970: 0)
        )
        let deletedId = UUID(uuidString: "40000000-0000-0000-0000-000000000003")!
        let syncedCarriers = LockIsolated<[Carrier]?>(nil)
        let store = await TestStore(
            initialState: CarrierManagementFeature.State()
        ) {
            CarrierManagementFeature()
        } withDependencies: {
            $0.carrierClient.delete = { _ in }
            $0.carrierClient.fetchAll = { [remaining] }
            $0.userSettingsAdapter.string = { _ in "" }
            $0.widgetSyncAdapter.syncAllCarriers = { carriers in
                syncedCarriers.setValue(carriers)
            }
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
        await store.receive(\.carriersLoaded) {
            $0.carriers = [remaining]
        }
        #expect(syncedCarriers.value == [remaining])
    }

    @Test("save delegate triggers syncAllCarriers with refreshed list")
    func testSaveDelegateTriggersSyncAllCarriers() async {
        let saved = Carrier(
            id: UUID(uuidString: "40000000-0000-0000-0000-000000000004")!,
            name: "New",
            type: .phoneBarcodeCarrier,
            barcode: "/ZZZ9999",
            createdAt: Date(timeIntervalSince1970: 0)
        )
        let syncedCarriers = LockIsolated<[Carrier]?>(nil)
        var initial = CarrierManagementFeature.State()
        initial.addEdit = AddEditCarrierFeature.State(mode: .add)
        let store = await TestStore(initialState: initial) {
            CarrierManagementFeature()
        } withDependencies: {
            $0.carrierClient.fetchAll = { [saved] }
            $0.userSettingsAdapter.string = { _ in "" }
            $0.userSettingsAdapter.setString = { _, _ in }
            $0.widgetSyncAdapter.syncCarrier = { _, _, _ in }
            $0.widgetSyncAdapter.syncAllCarriers = { carriers in
                syncedCarriers.setValue(carriers)
            }
        }

        await store.send(\.addEdit.presented.delegate.saved) {
            $0.addEdit = nil
        }
        await store.receive(\.carriersLoaded) {
            $0.carriers = [saved]
        }
        #expect(syncedCarriers.value == [saved])
    }
}
