import Foundation
import Dependencies
import Domain

/// Composition-root entry point for the iPhone side of the Watch bridge.
///
/// Must be called once at process launch (i.e. `App.init()`) — *not* after
/// any UI lifecycle event like splash completion. WatchConnectivity wakes
/// the iPhone app in the background to deliver queued `transferUserInfo`
/// payloads, and the system dispatches `WCSessionDelegate` callbacks
/// shortly after launch returns. Anything registered later than that
/// risks dropping background-delivered drafts.
///
/// Idempotent: repeated calls are no-ops.
@MainActor
public enum WatchBootstrap {

    private static var started = false
    private static var inboundDelegate: WatchSessionDelegate?
    private static var syncObserver: WatchSyncObserver?

    public static func start() {
        guard !started else { return }
        started = true

        #if canImport(WatchConnectivity)
        let transport = LiveWatchSessionTransport.shared
        // 1. Wire inbound handler BEFORE activate so WC can't dispatch into
        //    a nil handler on first delivery.
        let delegate = WatchSessionDelegate(transport: transport)
        delegate.start()
        inboundDelegate = delegate
        // 2. Activate — `LiveWatchSessionTransport.activate()` guards
        //    against double-activation, so it's safe to call here even
        //    though `WatchBridgeAdapter+Live` also calls it lazily.
        transport.activate()
        #endif

        // 3. Outbound: push a fresh snapshot whenever SwiftData saves.
        @Dependency(\.userSettingsRepository) var userSettings
        let observer = WatchSyncObserver(defaultAccountIdProvider: { @Sendable in
            let raw = userSettings.string(.watchDefaultAccountId)
            return raw.isEmpty ? nil : raw
        })
        observer.start()
        syncObserver = observer
    }
}
