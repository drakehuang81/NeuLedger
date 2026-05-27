import Foundation

/// Seam over `WCSession` so the iPhone-side delegate / adapter can be
/// unit-tested without launching the framework. Apple does not expose a
/// protocol form of `WCSession`; this is the smallest surface our code
/// actually uses.
///
/// Receivers register via `onReceiveUserInfo` (Watch → iPhone draft
/// hand-off). Senders use `updateApplicationContext` (iPhone → Watch
/// snapshot push). Both calls use Foundation types only so the seam is
/// platform-agnostic and Codable-friendly.
public protocol WatchSessionTransport: AnyObject, Sendable {

    /// `true` once `WCSession.activate()` has reported
    /// `.activated`. Adapter callers may push before activation; the
    /// transport buffers internally.
    var isActivated: Bool { get }

    /// `true` if the framework reports a paired Watch.
    var isPaired: Bool { get }

    /// `true` if the watchOS companion app is installed on the paired Watch.
    var isWatchAppInstalled: Bool { get }

    /// Begin the activation handshake. Idempotent — calling more than once
    /// is a no-op.
    func activate()

    /// Push the latest snapshot. WC's `updateApplicationContext` retains
    /// only the most recent dictionary, so callers send a full snapshot
    /// every time.
    func updateApplicationContext(_ context: [String: Any]) throws

    /// Register a handler for inbound `transferUserInfo` payloads (used by
    /// the Watch → iPhone draft path). Setting a new handler replaces the
    /// previous one.
    func onReceiveUserInfo(_ handler: @escaping @Sendable ([String: Any]) -> Void)
}
