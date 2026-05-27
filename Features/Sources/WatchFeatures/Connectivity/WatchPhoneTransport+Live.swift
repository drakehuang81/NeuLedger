#if canImport(WatchConnectivity)
import Foundation
import WatchConnectivity

/// `WCSession`-backed Watch-side transport. Also serves as the
/// `WCSessionDelegate`.
public final class LiveWatchPhoneTransport: NSObject, WatchPhoneTransport, WCSessionDelegate, @unchecked Sendable {

    public static let shared = LiveWatchPhoneTransport()

    private let lock = NSLock()
    private var contextHandler: (@Sendable ([String: Any]) -> Void)?
    private var didActivate = false

    public var isActivated: Bool {
        guard WCSession.isSupported() else { return false }
        return WCSession.default.activationState == .activated
    }

    public var isReachable: Bool {
        guard WCSession.isSupported() else { return false }
        return WCSession.default.isReachable
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

    public func sendUserInfo(_ payload: [String: Any]) {
        guard WCSession.isSupported() else { return }
        WCSession.default.transferUserInfo(payload)
    }

    public func onReceiveApplicationContext(
        _ handler: @escaping @Sendable ([String: Any]) -> Void
    ) {
        lock.lock(); defer { lock.unlock() }
        contextHandler = handler
    }

    public func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {}

    public func session(_ session: WCSession, didReceiveApplicationContext context: [String: Any]) {
        let handler: (@Sendable ([String: Any]) -> Void)? = {
            lock.lock(); defer { lock.unlock() }
            return contextHandler
        }()
        handler?(context)
    }
}
#endif
