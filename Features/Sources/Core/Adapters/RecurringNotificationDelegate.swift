import Foundation
import UserNotifications
import Domain

// MARK: - RecurringNotificationDelegate

/// 註冊為通知中心 delegate，讓 App 在前景時仍然顯示橫幅。
///
/// 自動入帳改由 `LedgerClient.tick()` 在 App 進前景時處理（health-audit A2），
/// 所以這裡不再需要把點擊事件廣播給任何人——點通知只要把 App 帶到前景就夠了。
final class RecurringNotificationDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {

    static let shared = RecurringNotificationDelegate()

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}

// MARK: - NotificationCenterBootstrap

/// Composition-root entry point that registers `RecurringNotificationDelegate`
/// as the notification center delegate.
///
/// Before the notification-tap confirmation flow was removed, the singleton
/// was created (and thus registered) lazily on first access of the adapter's
/// now-deleted confirmation-stream property. That access path is gone, so
/// something must eagerly force initialization — call this once from the
/// app's composition root (`AppView.init()`).
public enum NotificationCenterBootstrap {
    public static func start() {
        _ = RecurringNotificationDelegate.shared
    }
}
