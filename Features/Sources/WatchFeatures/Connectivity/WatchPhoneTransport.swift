import Foundation

/// Watch-side seam over `WCSession`. Mirrors Phase 1's iPhone-side
/// `WatchSessionTransport` (in Core) but with reversed traffic
/// direction:
///
/// - Watch **receives** snapshots via `onReceiveApplicationContext`
///   (iPhone pushes through `updateApplicationContext`).
/// - Watch **sends** drafts via `sendUserInfo` (queued by
///   `transferUserInfo`; survives reachability outages).
///
/// Apple does not expose a protocol form of `WCSession`; this protocol
/// is the minimum surface our delegate uses, mockable in tests.
public protocol WatchPhoneTransport: AnyObject, Sendable {
    var isActivated: Bool { get }
    var isReachable: Bool { get }
    func activate()
    func sendUserInfo(_ payload: [String: Any])
    func onReceiveApplicationContext(
        _ handler: @escaping @Sendable ([String: Any]) -> Void
    )
}
