import Foundation
import Dependencies
import Domain

extension WatchBridgeAdapter: DependencyKey {

    public static var liveValue: WatchBridgeAdapter {
        let transport: WatchSessionTransport = {
            #if canImport(WatchConnectivity)
            return LiveWatchSessionTransport.shared
            #else
            return UnavailableWatchSessionTransport()
            #endif
        }()
        transport.activate()

        return WatchBridgeAdapter(
            isPaired: { transport.isPaired },
            isWatchAppInstalled: { transport.isWatchAppInstalled },
            pushContext: { snapshot in
                let data = try JSONEncoder().encode(snapshot)
                let context: [String: Any] = [
                    "v": 1,
                    "snapshot": data
                ]
                try transport.updateApplicationContext(context)
            }
        )
    }
}

#if !canImport(WatchConnectivity)
/// Fallback for non-iOS targets that still link Core but cannot use WC.
private final class UnavailableWatchSessionTransport: WatchSessionTransport, @unchecked Sendable {
    var isActivated: Bool { false }
    var isPaired: Bool { false }
    var isWatchAppInstalled: Bool { false }
    func activate() {}
    func updateApplicationContext(_ context: [String: Any]) throws {}
    func onReceiveUserInfo(_ handler: @escaping @Sendable ([String: Any]) -> Void) {}
}
#endif
