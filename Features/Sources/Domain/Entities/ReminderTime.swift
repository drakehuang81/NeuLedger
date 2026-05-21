import Foundation

/// A wall-clock hour/minute used to schedule the daily recording
/// reminder notification.
///
/// Pure value type. No time zone, no Date — the corresponding
/// notification trigger (`UNCalendarNotificationTrigger`) interprets
/// the components in the user's current calendar at fire time.
public struct ReminderTime: Equatable, Hashable, Sendable {
    public let hour: Int
    public let minute: Int

    public init(hour: Int, minute: Int) {
        self.hour = hour
        self.minute = minute
    }
}
