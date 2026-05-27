import Foundation
import Domain

extension AccountClient {

    /// Watch-side live value. Read methods consult `WatchCacheStore`;
    /// mutation methods stay unimplemented (Watch has no entry point for
    /// editing accounts).
    public static func watchLive(cache: WatchCacheStore) -> AccountClient {
        var client = AccountClient()
        client.fetchAll = { @Sendable in
            cache.load()?.accounts ?? []
        }
        client.fetchActive = { @Sendable in
            (cache.load()?.accounts ?? []).filter { $0.isArchived == false }
        }
        return client
    }
}
