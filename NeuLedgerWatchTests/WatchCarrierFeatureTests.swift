import Foundation
import Testing
import Dependencies
import Domain
import ComposableArchitecture
@testable import WatchFeatures

@MainActor
@Suite("WatchCarrierFeature Tests")
struct WatchCarrierFeatureTests {

    private static let phone = Carrier(
        id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
        name: "手機條碼", type: .phoneBarcodeCarrier,
        barcode: "/AB12+CD",
        createdAt: Date(timeIntervalSince1970: 0)
    )

    private static let cert = Carrier(
        id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
        name: "自然人憑證", type: .citizenDigitalCertificate,
        barcode: "AB12345678901234",
        createdAt: Date(timeIntervalSince1970: 0)
    )

    @Test("Task loads carriers from the client")
    func taskLoadsCarriers() async {
        let store = TestStore(initialState: WatchCarrierFeature.State()) {
            WatchCarrierFeature()
        } withDependencies: {
            $0.watchCarrierClient.carriers = { @Sendable in [Self.phone] }
        }

        // `.task` 持有通知訂閱長存 effect——斷言完成後明確取消。
        let task = await store.send(.task)
        await store.receive(\.carriersUpdated) {
            $0.carriers = [Self.phone]
        }
        await task.cancel()
    }

    @Test("Tapping a row presents that carrier's barcode")
    func tapPresentsBarcode() async {
        let store = TestStore(
            initialState: WatchCarrierFeature.State(carriers: [Self.phone, Self.cert])
        ) {
            WatchCarrierFeature()
        }

        await store.send(.carrierTapped(Self.cert.id)) {
            $0.presentedCarrierID = Self.cert.id
        }
        await store.send(.barcodeDismissed) {
            $0.presentedCarrierID = nil
        }
    }

    @Test("Cache update re-resolves the presented carrier by id")
    func updateReresolvesPresented() async {
        var renamed = Self.phone
        renamed.name = "新名字"

        let store = TestStore(
            initialState: WatchCarrierFeature.State(
                carriers: [Self.phone, Self.cert],
                presentedCarrierID: Self.phone.id
            )
        ) {
            WatchCarrierFeature()
        }

        await store.send(.carriersUpdated([renamed, Self.cert])) {
            $0.carriers = [renamed, Self.cert]
        }
        #expect(store.state.presentedCarrier == renamed)
    }

    @Test("Cache update dismisses the presented carrier when it was deleted")
    func updateDismissesDeletedPresented() async {
        let store = TestStore(
            initialState: WatchCarrierFeature.State(
                carriers: [Self.phone, Self.cert],
                presentedCarrierID: Self.cert.id
            )
        ) {
            WatchCarrierFeature()
        }

        await store.send(.carriersUpdated([Self.phone])) {
            $0.carriers = [Self.phone]
        }
        #expect(store.state.presentedCarrier == nil)
    }

    @Test("Sync state degrades to nil when the cache empties")
    func updateToNilClearsList() async {
        let store = TestStore(
            initialState: WatchCarrierFeature.State(carriers: [Self.phone])
        ) {
            WatchCarrierFeature()
        }

        await store.send(.carriersUpdated(nil)) {
            $0.carriers = nil
        }
    }
}
