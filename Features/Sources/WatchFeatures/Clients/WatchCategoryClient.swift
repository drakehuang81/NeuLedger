import Foundation
import Domain

extension CategoryClient {

    /// Watch-side live value. All read methods consult `WatchCacheStore`;
    /// mutation methods remain at their `@DependencyClient` defaults
    /// because Watch has no UI for category mutation.
    public static func watchLive(cache: WatchCacheStore) -> CategoryClient {
        var client = CategoryClient()
        client.fetchAll = { @Sendable in
            cache.load()?.categories ?? []
        }
        client.fetchByType = { @Sendable type in
            (cache.load()?.categories ?? []).filter { $0.type == type }
        }
        return client
    }
}
