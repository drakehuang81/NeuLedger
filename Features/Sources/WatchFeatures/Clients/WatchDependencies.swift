import Foundation
import Dependencies
import Domain

/// Wires the Watch-flavored live value onto `DependencyValues` so any
/// reducer that takes `@Dependency(\.watchLedgerClient)` behaves
/// correctly when running inside the watchOS app.
///
/// Called from `NeuLedgerWatchApp.init()` via TCA's `prepareDependencies`.
public enum WatchDependencies {

    public static func register(in dependencies: inout DependencyValues) {
        let cache = WatchCacheStore()
#if canImport(WatchConnectivity)
        let gateway = WatchSessionGateway(
            transport: LiveWatchPhoneTransport.shared,
            cache: cache
        )
        gateway.start()
        dependencies.watchLedgerClient = .watchLive(cache: cache, gateway: gateway)
#endif
    }
}
