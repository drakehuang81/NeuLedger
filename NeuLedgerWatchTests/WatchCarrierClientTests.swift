import Foundation
import Testing
import Domain
@testable import WatchFeatures

@Suite("WatchCarrierClient Tests")
struct WatchCarrierClientTests {

    private func makeCache() -> WatchCacheStore {
        let suite = "WatchCarrierClientTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return WatchCacheStore(defaults: defaults)
    }

    private func makeSnapshot(carriers: [Carrier]?) -> WatchContextSnapshot {
        WatchContextSnapshot(
            categories: [], accounts: [], defaultAccountId: "ACC-1",
            todayTotal: 0, todayCount: 0, monthBudgetProgress: nil,
            snapshotAt: Date(timeIntervalSince1970: 1_700_000_000),
            carriers: carriers
        )
    }

    @Test("Empty cache yields nil (not yet synced)")
    func emptyCacheYieldsNil() async {
        let client = WatchCarrierClient.watchLive(cache: makeCache())
        #expect(await client.carriers() == nil)
    }

    @Test("Snapshot without carriers field yields nil")
    func legacySnapshotYieldsNil() async {
        let cache = makeCache()
        cache.save(makeSnapshot(carriers: nil))
        let client = WatchCarrierClient.watchLive(cache: cache)
        #expect(await client.carriers() == nil)
    }

    @Test("Snapshot carriers come back in order")
    func carriersPreserveOrder() async {
        let cache = makeCache()
        let first = Carrier(name: "手機條碼", type: .phoneBarcodeCarrier, barcode: "/AB12+CD")
        let second = Carrier(
            name: "自然人憑證", type: .citizenDigitalCertificate,
            barcode: "AB12345678901234"
        )
        cache.save(makeSnapshot(carriers: [first, second]))
        let client = WatchCarrierClient.watchLive(cache: cache)
        #expect(await client.carriers() == [first, second])
    }

    @Test("Empty carriers array stays empty (synced, none stored)")
    func emptyCarriersStayEmpty() async {
        let cache = makeCache()
        cache.save(makeSnapshot(carriers: []))
        let client = WatchCarrierClient.watchLive(cache: cache)
        #expect(await client.carriers() == [])
    }
}
