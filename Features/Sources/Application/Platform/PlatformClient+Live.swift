import Foundation
import Dependencies
import Domain
import SwiftData
import FirebaseCrashlytics

#if canImport(UIKit)
import UIKit
#endif

/// Live implementation of `PlatformClient`.
///
/// Assembled from the former `AppEnvironmentUseCase+Live` (preferences,
/// notifications, app-settings), `CloudSyncUseCase+Live` (iCloud sync), and
/// `DeeplinkClient+Live` (link routing). Persistence-backed routing reads
/// recurring templates directly through
/// `RecurringTransactionStore` (no
/// repository indirection). All preference round-trips go through
/// `\.userSettingsAdapter` under their existing `SettingsKey`s; notification
/// work delegates to `\.notificationAdapter`; iCloud lifecycle delegates to
/// `\.cloudKitSyncAdapter`.
extension PlatformClient: DependencyKey {
    public static var liveValue: PlatformClient {
        @Dependency(\.userSettingsAdapter) var userSettingsAdapter
        @Dependency(\.notificationAdapter) var notificationAdapter
        @Dependency(\.cloudKitSyncAdapter) var cloudKitSyncAdapter
        @Dependency(\.watchBridgeAdapter) var watchBridgeAdapter

        let recurringStore = RecurringTransactionStore()

        let capturedCloudKitSyncAdapter = cloudKitSyncAdapter
        let capturedUserSettingsAdapter = userSettingsAdapter

        return PlatformClient(
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
            hasCompletedOnboarding: { userSettingsAdapter.bool(.hasCompletedOnboarding) },
            markOnboardingComplete: {
                userSettingsAdapter.setBool(true, .hasCompletedOnboarding)
            },
            showAccessoryBar: { userSettingsAdapter.bool(.showAccessoryBar) },
            setShowAccessoryBar: { visible in
                userSettingsAdapter.setBool(visible, .showAccessoryBar)
            },
            watchPaired: { watchBridgeAdapter.isPaired() },
            watchAppInstalled: { watchBridgeAdapter.isWatchAppInstalled() },
            watchDefaultAccountId: {
                let raw = userSettingsAdapter.string(.watchDefaultAccountId)
                return raw.isEmpty ? nil : raw
            },
            setWatchDefaultAccountId: { id in
                userSettingsAdapter.setString(id ?? "", .watchDefaultAccountId)
            },

            // MARK: Notification
            requestNotificationPermission: {
                await notificationAdapter.requestAuthorization()
            },
            notificationsAuthorized: {
                await notificationAdapter.isAuthorized()
            },
            scheduleDailyReminder: {
                let hour = userSettingsAdapter.int(.dailyReminderHour)
                let minute = userSettingsAdapter.int(.dailyReminderMinute)
                try await notificationAdapter.scheduleDailyReminder(hour, minute)
            },
            cancelDailyReminder: {
                await notificationAdapter.cancelDailyReminder()
            },
            pendingRecurringConfirmations: {
                notificationAdapter.pendingConfirmations()
            },

            // MARK: Sync
            syncAvailable: {
                cloudKitSyncAdapter.isAvailable()
            },
            syncEnabled: {
                userSettingsAdapter.bool(.isSyncEnabled)
            },
            lastSyncedAt: {
                userSettingsAdapter.date(.lastSyncedAt)
            },
            enableSync: {
                AsyncThrowingStream { continuation in
                    let task = Task {
                        do {
                            continuation.yield(0.2)
                            try await capturedCloudKitSyncAdapter.switchToCloudContainer()
                            continuation.yield(0.8)

                            capturedUserSettingsAdapter.setBool(true, .isSyncEnabled)
                            capturedUserSettingsAdapter.setDate(Date(), .lastSyncedAt)

                            continuation.yield(1.0)
                            continuation.finish()
                        } catch {
                            continuation.finish(throwing: error)
                        }
                    }
                    continuation.onTermination = { _ in task.cancel() }
                }
            },
            requestSyncNow: {
                await cloudKitSyncAdapter.flushPendingChanges()
                userSettingsAdapter.setDate(Date(), .lastSyncedAt)
            },
            wipeAllSyncData: {
                // Order matters:
                //   1. Tear down cloud first so subsequent local saves don't
                //      stream half-deleted state back up to CloudKit.
                //   2. Wipe local rows.
                //   3. Rebuild the live ModelContainer against the local-only
                //      configuration so the next launch starts fresh.
                //   4. Clear preference flags last; once `hasCompletedOnboarding`
                //      flips false the UI layer routes back to onboarding.
                try await capturedCloudKitSyncAdapter.wipeCloudRecords()

                try await MainActor.run {
                    let context = ModelContext(PersistenceBootstrap.container)
                    try context.delete(model: SDTransaction.self)
                    try context.delete(model: SDAccount.self)
                    try context.delete(model: SDCategory.self)
                    try context.delete(model: SDBudget.self)
                    try context.delete(model: SDTag.self)
                    try context.delete(model: SDRecurringTransaction.self)
                    try context.delete(model: SDCarrier.self)
                    try context.save()

                    // Rebuild as a local-only container so the next
                    // `seedIfNeeded` runs without re-pulling stale cloud rows.
                    let localContainer = try ModelContainer(
                        for: PersistenceBootstrap.schema,
                        configurations: [PersistenceBootstrap.localConfiguration]
                    )
                    PersistenceBootstrap.container = localContainer
                }

                capturedUserSettingsAdapter.setBool(false, .isSyncEnabled)
                capturedUserSettingsAdapter.setBool(false, .hasCompletedOnboarding)
                capturedUserSettingsAdapter.setDate(nil, .lastSyncedAt)
            },

            // MARK: Routing
            parseLink: { url in
                guard url.scheme == "neuledger" else { return .none }
                switch url.host {
                case "carrier-management":
                    return .carrierManagement
                default:
                    return .none
                }
            },
            canSkipOnboarding: {
                userSettingsAdapter.bool(.hasCompletedOnboarding)
            },
            resolveRecurringConfirmation: { id in
                let all = try await recurringStore.fetchAll()
                guard let template = all.first(where: { $0.id == id }) else { return .none }
                return .recurringConfirmation(template)
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
            },
            recordError: { error, userInfo in
                Crashlytics.crashlytics().record(error: error, userInfo: userInfo)
            }
        )
    }
}
