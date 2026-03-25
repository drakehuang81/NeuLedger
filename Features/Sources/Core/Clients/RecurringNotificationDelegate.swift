import Foundation
import UserNotifications
import Domain

// MARK: - RecurringNotificationDelegate

/// A UNUserNotificationCenterDelegate that intercepts taps on recurring-transaction
/// notifications and broadcasts the associated `RecurringTransaction.ID` to all
/// active `pendingConfirmations` streams.
///
/// The singleton is registered as the notification center delegate once on first
/// access. Because `UNUserNotificationCenter.delegate` is a weak reference, the
/// singleton pattern keeps it alive for the app's lifetime.
final class RecurringNotificationDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {

    static let shared = RecurringNotificationDelegate()

    private let lock = NSLock()
    private var continuations: [UUID: AsyncStream<RecurringTransaction.ID>.Continuation] = [:]

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    // MARK: - Public API

    /// Returns a new stream that emits `RecurringTransaction.ID` values whenever
    /// the user taps a recurring-transaction notification.
    func confirmationStream() -> AsyncStream<RecurringTransaction.ID> {
        let streamId = UUID()
        let (stream, continuation) = AsyncStream<RecurringTransaction.ID>.makeStream(bufferingPolicy: .bufferingNewest(1))
        continuation.onTermination = { [weak self] _ in
            self?.removeContinuation(id: streamId)
        }
        lock.lock()
        continuations[streamId] = continuation
        lock.unlock()
        return stream
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        defer { completionHandler() }

        let userInfo = response.notification.request.content.userInfo
        guard
            let rawId = userInfo["recurringTransactionId"] as? String,
            let id = UUID(uuidString: rawId)
        else { return }

        lock.lock()
        let snapshot = continuations
        lock.unlock()

        for (_, continuation) in snapshot {
            continuation.yield(id)
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    // MARK: - Private

    private func removeContinuation(id: UUID) {
        lock.lock()
        continuations.removeValue(forKey: id)
        lock.unlock()
    }
}
