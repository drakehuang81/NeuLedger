import Foundation
import Domain

/// `WatchContextSnapshot` persisted in the Watch-side App Group's
/// `UserDefaults`, so the Watch app and (Phase 3) the Complication
/// widget extension can read the same latest snapshot.
///
/// Always writes the full snapshot — iPhone never sends deltas (see
/// `WatchContextSnapshot` doc comment).
public final class WatchCacheStore: @unchecked Sendable {

    /// App Group identifier configured on the watchOS target.
    /// Matches the entitlement set up in Phase 2 scaffold.
    public static let appGroupSuite = "group.com.drake.NeuLedger"

    /// Posted on `NotificationCenter.default` whenever a fresh snapshot has
    /// been persisted. UI observers reload from the cache on receipt.
    public static let didUpdateNotification = Notification.Name("WatchCacheStore.didUpdate")

    private static let storageKey = "watch.context_snapshot.v1"

    private let defaults: UserDefaults
    private let lock = NSLock()

    public init(defaults: UserDefaults = UserDefaults(suiteName: WatchCacheStore.appGroupSuite) ?? .standard) {
        self.defaults = defaults
    }

    public func load() -> WatchContextSnapshot? {
        lock.lock(); defer { lock.unlock() }
        guard let data = defaults.data(forKey: Self.storageKey) else { return nil }
        return try? JSONDecoder().decode(WatchContextSnapshot.self, from: data)
    }

    public func save(_ snapshot: WatchContextSnapshot) {
        lock.lock()
        guard let data = try? JSONEncoder().encode(snapshot) else { lock.unlock(); return }
        defaults.set(data, forKey: Self.storageKey)
        lock.unlock()
        NotificationCenter.default.post(name: Self.didUpdateNotification, object: nil)
    }
}
