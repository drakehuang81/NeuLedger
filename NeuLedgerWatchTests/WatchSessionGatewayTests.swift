import Foundation
import Testing
import Domain
import ConcurrencyExtras
@testable import WatchFeatures

@Suite("WatchSessionGateway Tests")
struct WatchSessionGatewayTests {

    final class FakeTransport: WatchPhoneTransport, @unchecked Sendable {
        var isActivated = false
        var isReachable = true

        let sentUserInfo = LockIsolated<[[String: Any]]>([])
        private var contextHandler: (@Sendable ([String: Any]) -> Void)?

        func activate() { isActivated = true }
        func sendUserInfo(_ payload: [String: Any]) {
            sentUserInfo.withValue { $0.append(payload) }
        }
        func onReceiveApplicationContext(
            _ handler: @escaping @Sendable ([String: Any]) -> Void
        ) {
            contextHandler = handler
        }
        func deliverContext(_ payload: [String: Any]) {
            contextHandler?(payload)
        }
    }

    private func makeCacheStore() -> WatchCacheStore {
        let suite = "WatchSessionGatewayTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return WatchCacheStore(defaults: defaults)
    }

    private func makeSnapshot() -> WatchContextSnapshot {
        WatchContextSnapshot(
            categories: [], accounts: [], defaultAccountId: UUID(),
            todayTotal: 420, todayCount: 1, monthBudgetProgress: nil,
            snapshotAt: Date()
        )
    }

    @Test("Inbound application context decodes and writes the cache")
    func inboundContextWritesCache() async throws {
        let transport = FakeTransport()
        let cache = makeCacheStore()
        let gateway = WatchSessionGateway(transport: transport, cache: cache)
        gateway.start()

        let snapshot = makeSnapshot()
        let data = try JSONEncoder().encode(snapshot)
        transport.deliverContext(["v": 1, "snapshot": data])

        try? await Task.sleep(nanoseconds: 50_000_000)
        #expect(cache.load()?.todayTotal == 420)
    }

    @Test("Malformed inbound context is ignored without writing cache")
    func malformedInboundIsIgnored() async throws {
        let transport = FakeTransport()
        let cache = makeCacheStore()
        let gateway = WatchSessionGateway(transport: transport, cache: cache)
        gateway.start()

        transport.deliverContext(["v": 1, "snapshot": "not-data"])
        try? await Task.sleep(nanoseconds: 50_000_000)
        #expect(cache.load() == nil)
    }

    @Test("Outbound draft is encoded under op=addTx and sent via transport")
    func outboundDraftIsSent() throws {
        let transport = FakeTransport()
        let cache = makeCacheStore()
        let gateway = WatchSessionGateway(transport: transport, cache: cache)
        let draft = TransactionDraft(
            categoryId: UUID(), accountId: UUID(), amount: 480
        )

        gateway.send(draft: draft)

        let sent = transport.sentUserInfo.value
        #expect(sent.count == 1)
        #expect(sent.first?["op"] as? String == "addTx")
        guard let data = sent.first?["payload"] as? Data else {
            Issue.record("payload missing or wrong type"); return
        }
        let decoded = try JSONDecoder().decode(TransactionDraft.self, from: data)
        #expect(decoded == draft)
    }
}
