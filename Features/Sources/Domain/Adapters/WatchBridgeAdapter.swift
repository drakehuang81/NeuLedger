import Foundation
import Dependencies
import DependenciesMacros

/// Outbound bridge from iPhone to Apple Watch. Mirrors the
/// `CloudKitSyncAdapter` shape — a low-level adapter wrapping the
/// `WCSession` lifecycle on the phone side. `WatchSyncUseCase`
/// (added in Phase 4) will orchestrate the broader flow.
///
/// The inbound side (Watch → iPhone `TransactionDraft` delivery) lives in
/// Core as `WatchSessionDelegate` because it's framework glue with no
/// stable domain interface.
@DependencyClient
public struct WatchBridgeAdapter: Sendable {
    /// `true` if a paired Apple Watch is currently associated with this
    /// iPhone. False if the device has never paired one, or pairing was
    /// removed.
    public var isPaired: @Sendable () -> Bool = { false }

    /// `true` if the watchOS companion app is installed on the paired
    /// Watch. False when paired but the user hasn't installed (or
    /// uninstalled) the Watch app.
    public var isWatchAppInstalled: @Sendable () -> Bool = { false }

    /// Push the latest snapshot to Watch via
    /// `WCSession.updateApplicationContext`. Errors propagate;
    /// `WatchSyncObserver` swallows them after logging because WC retries
    /// on its own schedule and a single failed push is not actionable.
    public var pushContext: @Sendable (WatchContextSnapshot) async throws -> Void
}

extension WatchBridgeAdapter: TestDependencyKey {
    public static let testValue = Self()
}

public extension DependencyValues {
    var watchBridgeAdapter: WatchBridgeAdapter {
        get { self[WatchBridgeAdapter.self] }
        set { self[WatchBridgeAdapter.self] = newValue }
    }
}
