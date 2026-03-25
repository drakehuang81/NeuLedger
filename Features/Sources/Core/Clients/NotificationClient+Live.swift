import Foundation
import UserNotifications
import Domain
import Dependencies

extension NotificationClient: DependencyKey {
    public static let liveValue = NotificationClient(

        requestAuthorization: {
            try? await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
            // requestAuthorization throws if called in extension context;
            // check resulting status rather than relying on the throw.
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            return settings.authorizationStatus == .authorized
        },

        scheduleDailyReminder: { hour, minute in
            let content = UNMutableNotificationContent()
            content.title = String(localized: "notification_daily_reminder_title", bundle: .main)
            content.body = String(localized: "notification_daily_reminder_body", bundle: .main)
            content.sound = .default

            var components = DateComponents()
            components.hour = hour
            components.minute = minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

            let request = UNNotificationRequest(
                identifier: "neuledger.daily_reminder",
                content: content,
                trigger: trigger
            )
            try? await UNUserNotificationCenter.current().add(request)
        },

        cancelDailyReminder: {
            UNUserNotificationCenter.current()
                .removePendingNotificationRequests(withIdentifiers: ["neuledger.daily_reminder"])
        },

        sendBudgetWarning: { budgetId, title, body in
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            let request = UNNotificationRequest(
                identifier: "neuledger.budget_warning.\(budgetId)",
                content: content,
                trigger: trigger
            )
            try? await UNUserNotificationCenter.current().add(request)
        },

        lastWarnedPercent: { budgetId, periodKey in
            UserDefaults.standard.object(
                forKey: "neuledger.budget_warned.\(budgetId).\(periodKey)"
            ) as? Int
        },

        setLastWarnedPercent: { percent, budgetId, periodKey in
            UserDefaults.standard.set(
                percent,
                forKey: "neuledger.budget_warned.\(budgetId).\(periodKey)"
            )
        },

        isAuthorized: {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            return settings.authorizationStatus == .authorized
        },

        scheduleRecurringReminder: { id, dueDate, title, body in
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            content.userInfo = ["recurringTransactionId": id.uuidString]

            let triggerDate = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: dueDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
            let request = UNNotificationRequest(
                identifier: "neuledger.recurring.\(id.uuidString)",
                content: content,
                trigger: trigger
            )
            try? await UNUserNotificationCenter.current().add(request)
        },

        cancelRecurringReminder: { id in
            UNUserNotificationCenter.current()
                .removePendingNotificationRequests(
                    withIdentifiers: ["neuledger.recurring.\(id.uuidString)"]
                )
        },

        pendingConfirmations: {
            RecurringNotificationDelegate.shared.confirmationStream()
        }
    )
}
