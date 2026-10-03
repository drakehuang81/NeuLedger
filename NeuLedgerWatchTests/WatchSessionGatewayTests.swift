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
        /// When set, `sendUserInfo` refuses to queue and throws this.
        var sendError: Error?
        private var contextHandler: (@Sendable ([String: Any]) -> Void)?

        func activate() { isActivated = true }
        func sendUserInfo(_ payload: [String: Any]) throws {
            if let sendError { throw sendError }
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
            categories: [], accounts: [], defaultAccountId: UUID().uuidString,
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
            categoryId: UUID(), accountId: UUID().uuidString, amount: 480
        )

        try gateway.send(draft: draft)

        let sent = transport.sentUserInfo.value
        #expect(sent.count == 1)
        #expect(sent.first?["op"] as? String == "addTx")
        guard let data = sent.first?["payload"] as? Data else {
            Issue.record("payload missing or wrong type"); return
        }
        let decoded = try JSONDecoder().decode(TransactionDraft.self, from: data)
        #expect(decoded == draft)
    }

    // MARK: - A1：送不出去時必須讓呼叫端知道

    @Test("An unreachable iPhone is not a failure — transferUserInfo still queues the draft")
    func unreachablePhoneIsNotAFailure() throws {
        // 這條測試固定住本次修正的劃線方式：`transferUserInfo` 會排隊，
        // 使用者沒帶手機時記帳是正常用法，不可以報成失敗。
        let transport = FakeTransport()
        transport.isActivated = true
        transport.isReachable = false
        let gateway = WatchSessionGateway(transport: transport, cache: makeCacheStore())
        let draft = TransactionDraft(
            categoryId: UUID(), accountId: UUID().uuidString, amount: 120
        )

        try gateway.send(draft: draft)

        #expect(transport.sentUserInfo.value.count == 1)
    }

    @Test("A transport that cannot queue the payload surfaces the failure to the caller")
    func transportFailureIsSurfaced() {
        let transport = FakeTransport()
        transport.sendError = WatchSendFailure.sessionNotActivated
        let gateway = WatchSessionGateway(transport: transport, cache: makeCacheStore())
        let draft = TransactionDraft(
            categoryId: UUID(), accountId: UUID().uuidString, amount: 120
        )

        #expect(throws: WatchSendFailure.sessionNotActivated) {
            try gateway.send(draft: draft)
        }
        #expect(transport.sentUserInfo.value.isEmpty)
    }

    @Test(
        "Every send failure resolves to a real translation, not a raw key",
        arguments: WatchSendFailure.allCases
    )
    func everyFailureHasLocalizedMessage(failure: WatchSendFailure) {
        let message = failure.localizedMessage

        #expect(message.isEmpty == false)
        // `String(localized:)` 找不到 key 時會原封不動回傳 key 本身，
        // 所以訊息長得像 key 就表示 Localizable.xcstrings 漏了這條。
        #expect(
            message.hasPrefix("watch_") == false,
            "缺少 Watch app Localizable.xcstrings 的翻譯：\(message)"
        )
    }
}
