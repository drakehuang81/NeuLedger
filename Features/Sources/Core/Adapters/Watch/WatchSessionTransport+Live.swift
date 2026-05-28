#if canImport(WatchConnectivity)
import Foundation
import WatchConnectivity

/// `WCSession`-backed implementation of `WatchSessionTransport`.
///
/// The class also serves as the `WCSessionDelegate`. We retain only the
/// inbound handler (`onReceiveUserInfo`) — the higher-level
/// `WatchSessionDelegate` (Core) decodes the payload and writes through
/// `transactionClient`.
public final class LiveWatchSessionTransport: NSObject, WatchSessionTransport, WCSessionDelegate, @unchecked Sendable {

    public static let shared = LiveWatchSessionTransport()

    private let lock = NSLock()
    private var inboundHandler: (@Sendable ([String: Any]) -> Void)?
    private var didActivate = false
    /// Snapshots queued before `WCSession` finishes async activation. Apple
    /// throws `WCError.sessionNotActivated` if you write before activation,
    /// so we hold the most recent context here and flush on activation.
    private var pendingContext: [String: Any]?

    public var isActivated: Bool {
        guard WCSession.isSupported() else { return false }
        return WCSession.default.activationState == .activated
    }

    public var isPaired: Bool {
        guard WCSession.isSupported() else { return false }
        return WCSession.default.isPaired
    }

    public var isWatchAppInstalled: Bool {
        guard WCSession.isSupported() else { return false }
        return WCSession.default.isWatchAppInstalled
    }

    public func activate() {
        guard WCSession.isSupported() else { return }
        lock.lock()
        guard didActivate == false else { lock.unlock(); return }
        didActivate = true
        lock.unlock()
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    public func updateApplicationContext(_ context: [String: Any]) throws {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        if session.activationState != .activated {
            lock.lock(); pendingContext = context; lock.unlock()
            return
        }
        try session.updateApplicationContext(context)
    }

    public func onReceiveUserInfo(_ handler: @escaping @Sendable ([String: Any]) -> Void) {
        lock.lock(); defer { lock.unlock() }
        inboundHandler = handler
    }

    // MARK: WCSessionDelegate

    public func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        guard activationState == .activated else { return }
        let pending: [String: Any]? = {
            lock.lock(); defer { lock.unlock() }
            let p = pendingContext
            pendingContext = nil
            return p
        }()
        if let pending {
            try? session.updateApplicationContext(pending)
        }
    }

    public func sessionDidBecomeInactive(_ session: WCSession) {}

    public func sessionDidDeactivate(_ session: WCSession) {
        // Reactivate so a paired-device swap continues to work.
        WCSession.default.activate()
    }

    public func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        let handler: (@Sendable ([String: Any]) -> Void)? = {
            lock.lock(); defer { lock.unlock() }
            return inboundHandler
        }()
        handler?(userInfo)
    }
}
#endif
