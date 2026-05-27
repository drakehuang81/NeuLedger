import Foundation
import Domain
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

    public func send(draft: TransactionDraft) {
        guard let data = try? JSONEncoder().encode(draft) else { return }
        transport.sendUserInfo([
            "op": "addTx",
            "payload": data
        ])
    }

    private func handleContext(_ payload: [String: Any]) {
        guard let data = payload["snapshot"] as? Data else { return }
        guard let snapshot = try? JSONDecoder().decode(WatchContextSnapshot.self, from: data) else { return }
        cache.save(snapshot)
        #if canImport(WidgetKit)
        // Phase 3 will uncomment:
        // WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
