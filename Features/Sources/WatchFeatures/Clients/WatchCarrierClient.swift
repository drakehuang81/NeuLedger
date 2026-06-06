import Foundation
import Dependencies
import DependenciesMacros
import Domain

/// Watch-side carrier client — read-only by design. The Watch never
/// creates, edits, or deletes carriers; it renders whatever the iPhone
/// mirrored into the snapshot cache.
@DependencyClient
public struct WatchCarrierClient: Sendable {
    /// Carriers from the iPhone snapshot cache.
    /// `nil` = no snapshot yet, or the snapshot predates carrier support
    /// (UI shows a sync hint). `[]` = synced and genuinely none
    /// (UI shows add-on-iPhone guidance).
    public var carriers: @Sendable () async -> [Carrier]? = { nil }
}

extension WatchCarrierClient: TestDependencyKey {
    public static let testValue = Self()
}

public extension DependencyValues {
    var watchCarrierClient: WatchCarrierClient {
        get { self[WatchCarrierClient.self] }
        set { self[WatchCarrierClient.self] = newValue }
    }
}

extension WatchCarrierClient {

    /// Watch-side live value: a thin projection over `WatchCacheStore`.
    public static func watchLive(cache: WatchCacheStore) -> WatchCarrierClient {
        WatchCarrierClient(
            carriers: { cache.load()?.carriers }
        )
    }
}
