import Foundation
import Domain
import WidgetKit
#if canImport(WatchKit)
import WatchKit
#endif

/// The Watch app's single point of contact with the iPhone over
/// WatchConnectivity.
public final class WatchSessionGateway: @unchecked Sendable {

    private let transport: WatchPhoneTransport
    private let cache: WatchCacheStore

    public init(transport: WatchPhoneTransport, cache: WatchCacheStore) {
        self.transport = transport
        self.cache = cache
    }

    public func start() {
        transport.activate()
        transport.onReceiveApplicationContext { [weak self] payload in
            self?.handleContext(payload)
        }
    }

    /// Queues a draft for the iPhone. Throws `WatchSendFailure` when the
    /// draft could not be queued at all — the caller must keep the draft
    /// alive so the user can retry.
    public func send(draft: TransactionDraft) throws {
        let data: Data
        do {
            data = try JSONEncoder().encode(draft)
        } catch {
            throw WatchSendFailure.encodingFailed
        }
        try transport.sendUserInfo([
            "op": "addTx",
            "payload": data
        ])
    }

    private func handleContext(_ payload: [String: Any]) {
        guard let data = payload["snapshot"] as? Data else { return }
        guard let snapshot = try? JSONDecoder().decode(WatchContextSnapshot.self, from: data) else { return }
        cache.save(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
