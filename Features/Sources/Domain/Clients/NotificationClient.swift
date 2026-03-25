import Foundation
import Dependencies
import DependenciesMacros

// MARK: - NotificationClient

/// A client interface for scheduling and managing local notifications.
///
/// All UNUserNotificationCenter operations are abstracted here so that
/// feature reducers can be tested without a real notification system.
@DependencyClient
public struct NotificationClient: Sendable {
    /// Request UNUserNotificationCenter authorization. Returns true if granted.
    public var requestAuthorization: @Sendable () async -> Bool = { false }

    /// Schedule (or reschedule) the daily reminder at the given hour/minute.
    /// Using the same fixed identifier replaces any previous request automatically.
    public var scheduleDailyReminder: @Sendable (_ hour: Int, _ minute: Int) async -> Void = { _, _ in }

    /// Cancel the daily reminder.
    public var cancelDailyReminder: @Sendable () async -> Void = {}

    /// Fire a one-shot budget warning notification immediately.
    /// - Parameters:
    ///   - budgetId: Used as the unique notification identifier (UUID string).
    ///   - title: Pre-formatted, localized notification title.
    ///   - body: Pre-formatted, localized notification body.
    public var sendBudgetWarning: @Sendable (_ budgetId: String, _ title: String, _ body: String) async -> Void = { _, _, _ in }

    /// Read the last warned percent for a given budget + period key.
    /// Returns nil if no warning has been sent yet for this period.
    public var lastWarnedPercent: @Sendable (_ budgetId: String, _ periodKey: String) -> Int? = { _, _ in nil }

    /// Persist the warned percent for a given budget + period key.
    public var setLastWarnedPercent: @Sendable (_ percent: Int, _ budgetId: String, _ periodKey: String) -> Void = { _, _, _ in }

    /// Check current authorization status (true = .authorized).
    public var isAuthorized: @Sendable () async -> Bool = { false }

    /// Schedule a due-date notification for a recurring transaction.
    /// Using the recurring transaction's id as the notification identifier ensures
    /// scheduling the same template again replaces the previous request.
    public var scheduleRecurringReminder: @Sendable (
        _ id: RecurringTransaction.ID,
        _ dueDate: Date,
        _ title: String,
        _ body: String
    ) async -> Void = { _, _, _, _ in }

    /// Cancel the scheduled notification for a recurring transaction.
    public var cancelRecurringReminder: @Sendable (_ id: RecurringTransaction.ID) async -> Void = { _ in }

    /// Emits a `RecurringTransaction.ID` each time the user taps a recurring-transaction notification.
    /// The live implementation owns the UNUserNotificationCenterDelegate internally — no AppDelegate needed.
    /// testValue emits an immediately-finishing stream to prevent test hangs.
    public var pendingConfirmations: @Sendable () -> AsyncStream<RecurringTransaction.ID> = {
        let (stream, continuation) = AsyncStream<RecurringTransaction.ID>.makeStream()
        continuation.finish()
        return stream
    }
}

// MARK: - TestDependencyKey

extension NotificationClient: TestDependencyKey {
    public static let testValue = NotificationClient(
        requestAuthorization: { false },
        scheduleDailyReminder: { _, _ in },
        cancelDailyReminder: {},
        sendBudgetWarning: { _, _, _ in },
        lastWarnedPercent: { _, _ in nil },
        setLastWarnedPercent: { _, _, _ in },
        isAuthorized: { false },
        scheduleRecurringReminder: { _, _, _, _ in },
        cancelRecurringReminder: { _ in },
        pendingConfirmations: {
            let (stream, continuation) = AsyncStream<RecurringTransaction.ID>.makeStream()
            continuation.finish()
            return stream
        }
    )
}

// MARK: - DependencyValues

public extension DependencyValues {
    var notificationClient: NotificationClient {
        get { self[NotificationClient.self] }
        set { self[NotificationClient.self] = newValue }
    }
}
