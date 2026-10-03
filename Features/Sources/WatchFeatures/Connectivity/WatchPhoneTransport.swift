import Foundation

/// Why a draft could not be handed to WatchConnectivity.
///
/// Deliberately narrow: it only covers conditions under which the payload
/// **never enters the transfer queue**, i.e. the record is genuinely lost
/// unless the user retries.
///
/// In particular an unreachable or unpaired iPhone is *not* listed here.
/// `WCSession.transferUserInfo(_:)` queues its payload and keeps retrying
/// in the background, so recording with the phone out of range is a
/// normal, supported use of the Watch app — reporting it as a failure
/// would be a false alarm.
public enum WatchSendFailure: Error, Equatable, Sendable, CaseIterable {
    /// `WCSession.isSupported() == false` — this device has no
    /// WatchConnectivity at all, so nothing will ever be delivered.
    case sessionUnsupported

    /// `activate()` has not completed yet. Transient: a retry a moment
    /// later normally succeeds. Also guards against `transferUserInfo`
    /// raising an exception on a non-activated session.
    case sessionNotActivated

    /// `JSONEncoder` could not encode the draft, so there is no payload
    /// to queue.
    case encodingFailed

    /// The transaction carried no `categoryId`, which the iPhone side
    /// requires to materialise a transaction.
    case missingCategory

    /// The send path threw something we don't model.
    case unknown
}

public extension WatchSendFailure {

    /// User-facing wording, read from the Watch app's own
    /// `Localizable.xcstrings` (`Bundle.main` on watchOS).
    ///
    /// The keys are spelled as literals per case on purpose: a runtime
    /// `String.LocalizationValue` built from a key variable is not a key
    /// lookup, and would silently render the raw key.
    var localizedMessage: String {
        switch self {
        case .sessionUnsupported: String(localized: "watch_send_error_unsupported")
        case .sessionNotActivated: String(localized: "watch_send_error_not_ready")
        case .encodingFailed: String(localized: "watch_send_error_encoding")
        case .missingCategory: String(localized: "watch_send_error_no_category")
        case .unknown: String(localized: "watch_send_error_generic")
        }
    }
}

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

    /// Hands `payload` to the transfer queue. Throws `WatchSendFailure`
    /// only when the payload could not be queued at all; a successful
    /// return means "queued", not "delivered".
    func sendUserInfo(_ payload: [String: Any]) throws
    func onReceiveApplicationContext(
        _ handler: @escaping @Sendable ([String: Any]) -> Void
    )
}
