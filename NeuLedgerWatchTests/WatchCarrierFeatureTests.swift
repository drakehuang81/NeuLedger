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

    // MARK: - Task 3: carriersUpdated presented==nil branch

    /// 有 2+ 載具且無人被展示時收到更新：只刷新 carriers，
    /// presentedCarrierID 保持 nil（不應意外被設值）。
    /// 這也驗證了 rename 後 presentedCarrier computed 自動反映新 barcode。
    @Test("carriersUpdated with no presented carrier only refreshes the list")
    func updateWithNoPresentedOnlyRefreshesList() async {
        var renamedPhone = Self.phone
        renamedPhone.name = "手機條碼（新）"
        renamedPhone.barcode = "/ZZ99+WW"

        // Start with 2 carriers, presentedCarrierID is nil (no one is presented)
        let store = TestStore(
            initialState: WatchCarrierFeature.State(
                carriers: [Self.phone, Self.cert],
                presentedCarrierID: nil
            )
        ) {
            WatchCarrierFeature()
        }

        // carriersUpdated should update carriers without touching presentedCarrierID
        await store.send(.carriersUpdated([renamedPhone, Self.cert])) {
            $0.carriers = [renamedPhone, Self.cert]
            // presentedCarrierID stays nil — not mutated by the update
        }

        // presentedCarrierID is still nil
        #expect(store.state.presentedCarrierID == nil)
        // presentedCarrier computed also nil (no one selected)
        #expect(store.state.presentedCarrier == nil)

        // Now tap the renamed carrier — presentedCarrier reflects the new barcode
        await store.send(.carrierTapped(renamedPhone.id)) {
            $0.presentedCarrierID = renamedPhone.id
        }
        #expect(store.state.presentedCarrier?.barcode == "/ZZ99+WW")
    }
}
