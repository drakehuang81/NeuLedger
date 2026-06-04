import Foundation
import Dependencies
import Domain

#if canImport(UIKit)
import UIKit
#endif

extension AppEnvironmentUseCase: DependencyKey {
    public static var liveValue: AppEnvironmentUseCase {
        @Dependency(\.userSettingsAdapter) var userSettingsAdapter
        @Dependency(\.notificationAdapter) var notificationAdapter

        return AppEnvironmentUseCase(
            // MARK: Preferences
            accessoryMode: {
                let raw = userSettingsAdapter.string(.accessoryMode)
                return AccessoryMode(rawValue: raw) ?? .add
            },
            setAccessoryMode: { mode in
                userSettingsAdapter.setString(mode.rawValue, .accessoryMode)
            },
            reminderTime: {
                ReminderTime(
                    hour: userSettingsAdapter.int(.dailyReminderHour),
                    minute: userSettingsAdapter.int(.dailyReminderMinute)
                )
            },
            setReminderTime: { time in
                userSettingsAdapter.setInt(time.hour, .dailyReminderHour)
                userSettingsAdapter.setInt(time.minute, .dailyReminderMinute)
            },
            dailyReminderEnabled: { userSettingsAdapter.bool(.dailyReminderEnabled) },
            setDailyReminderEnabled: { enabled in
                userSettingsAdapter.setBool(enabled, .dailyReminderEnabled)
            },
            defaultAccountId: {
                let raw = userSettingsAdapter.string(.defaultAccountId)
                return raw.isEmpty ? nil : raw
            },
            setDefaultAccountId: { id in
                userSettingsAdapter.setString(id ?? "", .defaultAccountId)
            },
            hasCompletedOnboarding: { userSettingsAdapter.bool(.hasCompletedOnboarding) },
            markOnboardingComplete: {
                userSettingsAdapter.setBool(true, .hasCompletedOnboarding)
            },

            // MARK: Notifications
            requestNotificationPermission: {
                await notificationAdapter.requestAuthorization()
            },
            scheduleDailyReminder: {
                let hour = userSettingsAdapter.int(.dailyReminderHour)
                let minute = userSettingsAdapter.int(.dailyReminderMinute)
                try await notificationAdapter.scheduleDailyReminder(hour, minute)
            },
            cancelDailyReminder: {
                await notificationAdapter.cancelDailyReminder()
            },

            // MARK: System
            openAppSettings: {
                #if canImport(UIKit)
                Task { @MainActor in
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                #endif
            }
        )
    }
}
