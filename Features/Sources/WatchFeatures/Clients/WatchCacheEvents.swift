import Foundation
import Dependencies

/// 「iPhone 推了一份新快照」這個事件的串流。
///
/// 為什麼要抽成相依而不是直接讀 `NotificationCenter.default`：
/// `.task` 掛的是一條**長存**訂閱，而 `NotificationCenter.default` 是 process
/// 全域的。在平行跑的測試 runner 裡，任何一條測試只要碰到
/// `WatchCacheStore.save()` 就會發出這個通知，於是**別的測試**的訂閱會收到它，
/// 變成「未預期的 action」。這不是時序問題，是測試之間透過全域匯流排互相污染，
/// 而且會隨著測試數量增加而惡化（`WatchCarrierFeatureTests/taskLoadsCarriers`
/// 在完整 suite 下三次紅兩次、單獨跑三次全綠）。
///
/// `testValue` 回一條**不會發出任何東西**的串流：測試預設拿到確定性的行為，
/// 需要模擬「快照更新」的測試自己提供串流即可。
public struct WatchCacheEvents: Sendable {
    /// 每當一份新快照落地就發出一個元素。
    public var updates: @Sendable () -> AsyncStream<Void>

    public init(updates: @escaping @Sendable () -> AsyncStream<Void>) {
        self.updates = updates
    }
}

extension WatchCacheEvents: DependencyKey {
    public static let liveValue = WatchCacheEvents(
        updates: {
            AsyncStream { continuation in
                let task = Task {
                    for await _ in NotificationCenter.default.notifications(
                        named: WatchCacheStore.didUpdateNotification
                    ) {
                        continuation.yield(())
                    }
                    continuation.finish()
                }
                continuation.onTermination = { _ in task.cancel() }
            }
        }
    )

    /// 預設不發出任何事件——見型別說明。
    public static let testValue = WatchCacheEvents(
        updates: { AsyncStream { $0.finish() } }
    )
}

public extension DependencyValues {
    var watchCacheEvents: WatchCacheEvents {
        get { self[WatchCacheEvents.self] }
        set { self[WatchCacheEvents.self] = newValue }
    }
}
