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
