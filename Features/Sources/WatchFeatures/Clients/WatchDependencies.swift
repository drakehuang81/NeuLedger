import Foundation
import Dependencies
import Domain

/// Wires the Watch-flavored live values onto `DependencyValues` so any
/// reducer that takes `@Dependency(\.transactionClient)` etc. behaves
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
        dependencies.transactionClient = .watchLive(gateway: gateway)
#endif
        dependencies.categoryClient = .watchLive(cache: cache)
        dependencies.accountClient = .watchLive(cache: cache)
    }
}
