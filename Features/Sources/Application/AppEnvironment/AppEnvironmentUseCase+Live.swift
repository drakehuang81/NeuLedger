import Foundation
import Dependencies
import Domain

#if canImport(UIKit)
import UIKit
#endif

extension AppEnvironmentUseCase: DependencyKey {
    public static var liveValue: AppEnvironmentUseCase {
        @Dependency(\.userSettingsRepository) var userSettingsRepository
        @Dependency(\.notificationAdapter) var notificationAdapter

        return AppEnvironmentUseCase(
            // MARK: Preferences
            accessoryMode: {
                let raw = userSettingsRepository.string(.accessoryMode)
                return AccessoryMode(rawValue: raw) ?? .add
            },
            setAccessoryMode: { mode in
                userSettingsRepository.setString(mode.rawValue, .accessoryMode)
            },
            reminderTime: {
                ReminderTime(
                    hour: userSettingsRepository.int(.dailyReminderHour),
                    minute: userSettingsRepository.int(.dailyReminderMinute)
                )
            },
            setReminderTime: { time in
                userSettingsRepository.setInt(time.hour, .dailyReminderHour)
                userSettingsRepository.setInt(time.minute, .dailyReminderMinute)
            },
            dailyReminderEnabled: { userSettingsRepository.bool(.dailyReminderEnabled) },
            setDailyReminderEnabled: { enabled in
                userSettingsRepository.setBool(enabled, .dailyReminderEnabled)
            },
            budgetWarningEnabled: { userSettingsRepository.bool(.budgetWarningEnabled) },
            setBudgetWarningEnabled: { enabled in
                userSettingsRepository.setBool(enabled, .budgetWarningEnabled)
            },
            budgetWarningThreshold: { userSettingsRepository.int(.budgetWarningThreshold) },
            setBudgetWarningThreshold: { percent in
                userSettingsRepository.setInt(percent, .budgetWarningThreshold)
            },
            defaultAccountId: {
                let raw = userSettingsRepository.string(.defaultAccountId)
                return raw.isEmpty ? nil : raw
            },
            setDefaultAccountId: { id in
                userSettingsRepository.setString(id ?? "", .defaultAccountId)
            },
            hasCompletedOnboarding: { userSettingsRepository.bool(.hasCompletedOnboarding) },
            markOnboardingComplete: {
                userSettingsRepository.setBool(true, .hasCompletedOnboarding)
            },

            // MARK: Notifications
            requestNotificationPermission: {
                await notificationAdapter.requestAuthorization()
            },
            scheduleDailyReminder: {
                let hour = userSettingsRepository.int(.dailyReminderHour)
                let minute = userSettingsRepository.int(.dailyReminderMinute)
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
