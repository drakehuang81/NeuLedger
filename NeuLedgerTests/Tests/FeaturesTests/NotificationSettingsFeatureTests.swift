import Testing
import Foundation
import ComposableArchitecture
@testable import Features
import Domain

@Suite("NotificationSettingsFeature Tests")
struct NotificationSettingsFeatureTests {

    // MARK: - .task

    @Test(".task loads settings and checks authorization")
    func testTaskLoadsSettings() async throws {
        let store = await TestStore(initialState: NotificationSettingsFeature.State()) {
            NotificationSettingsFeature()
        } withDependencies: {
            $0.userSettingsAdapter.bool = { key in
                key.rawValue == SettingsKey<Bool>.dailyReminderEnabled.rawValue ? true : key.defaultValue
            }
            $0.userSettingsAdapter.int = { key in
                key.rawValue == SettingsKey<Int>.dailyReminderHour.rawValue ? 8 : key.defaultValue
            }
            $0.planningClient.warningEnabled = { false }
            $0.planningClient.warningThreshold = { 80 }
            $0.notificationAdapter.isAuthorized = { true }
            $0.recurringTransactionClient.fetchAll = { [] }
        }
        await MainActor.run {
            store.exhaustivity = .off
        }

        await store.send(.task) {
            $0.dailyReminderEnabled = true
            $0.reminderDate = Calendar.current.date(from: DateComponents(hour: 8, minute: 0))!
        }

        await store.receive(\.authorizationStatusLoaded) {
            $0.isAuthorized = true
        }
    }

    // MARK: - Daily Reminder Toggle

    @Test("toggling daily reminder on when authorized schedules notification")
    func testDailyReminderToggleOnAuthorized() async throws {
        let scheduledHour: LockIsolated<Int?> = LockIsolated(nil)
        let scheduledMinute: LockIsolated<Int?> = LockIsolated(nil)
        let persistedEnabled: LockIsolated<Bool?> = LockIsolated(nil)

        let store = await TestStore(
            initialState: NotificationSettingsFeature.State(isAuthorized: true)
        ) {
            NotificationSettingsFeature()
        } withDependencies: {
            $0.notificationAdapter.scheduleDailyReminder = { h, m in
                scheduledHour.setValue(h)
                scheduledMinute.setValue(m)
            }
            $0.userSettingsAdapter.setBool = { val, _ in persistedEnabled.setValue(val) }
            $0.userSettingsAdapter.setInt = { _, _ in }
        }

        await store.send(.dailyReminderToggled(true)) {
            $0.dailyReminderEnabled = true
        }

        #expect(scheduledHour.value == 21)  // default hour
        #expect(scheduledMinute.value == 0)
        #expect(persistedEnabled.value == true)
    }

    @Test("toggling daily reminder off cancels notification")
    func testDailyReminderToggleOff() async throws {
        let cancelCalled: LockIsolated<Bool> = LockIsolated(false)

        let store = await TestStore(
            initialState: NotificationSettingsFeature.State(
                dailyReminderEnabled: true,
                isAuthorized: true
            )
        ) {
            NotificationSettingsFeature()
        } withDependencies: {
            $0.notificationAdapter.cancelDailyReminder = { cancelCalled.setValue(true) }
            $0.userSettingsAdapter.setBool = { _, _ in }
        }

        await store.send(.dailyReminderToggled(false)) {
            $0.dailyReminderEnabled = false
        }

        #expect(cancelCalled.value == true)
    }

    // MARK: - Permission Denied

    @Test("toggling on when unauthorized requests permission; denial shows banner")
    func testToggleOnUnauthorizedDenied() async throws {
        let setBoolCalled: LockIsolated<Bool> = LockIsolated(false)

        let store = await TestStore(
            initialState: NotificationSettingsFeature.State(isAuthorized: false)
        ) {
            NotificationSettingsFeature()
        } withDependencies: {
            $0.notificationAdapter.requestAuthorization = { false }  // denied
            $0.notificationAdapter.scheduleDailyReminder = { _, _ in }
            $0.userSettingsAdapter.setBool = { _, _ in setBoolCalled.setValue(true) }
            $0.userSettingsAdapter.setInt = { _, _ in }
        }

        await store.send(.dailyReminderToggled(true))
        await store.receive(\.permissionDenied) {
            $0.showPermissionDeniedBanner = true
        }

        #expect(setBoolCalled.value == false, "Should not persist when permission denied")
    }

    // MARK: - Banner Self-Heal

    @Test(".task self-heals banner when permission granted in system Settings")
    func testBannerSelfHeals() async throws {
        let store = await TestStore(
            initialState: NotificationSettingsFeature.State(
                isAuthorized: false,
                showPermissionDeniedBanner: true
            )
        ) {
            NotificationSettingsFeature()
        } withDependencies: {
            $0.notificationAdapter.isAuthorized = { true }  // user granted permission in Settings
            $0.userSettingsAdapter.bool = { $0.defaultValue }
            $0.userSettingsAdapter.int = { $0.defaultValue }
            $0.planningClient.warningEnabled = { false }
            $0.planningClient.warningThreshold = { 80 }
            $0.recurringTransactionClient.fetchAll = { [] }
        }
        await MainActor.run {
            store.exhaustivity = .off
        }

        await store.send(.task)
        await store.receive(\.authorizationStatusLoaded) {
            $0.isAuthorized = true
            $0.showPermissionDeniedBanner = false
        }
    }

    // MARK: - Reminder Time

    @Test("reminderDateChanged reschedules and persists hour/minute")
    func testReminderDateChanged() async throws {
        let savedHour: LockIsolated<Int?> = LockIsolated(nil)
        let savedMinute: LockIsolated<Int?> = LockIsolated(nil)

        let store = await TestStore(
            initialState: NotificationSettingsFeature.State(
                dailyReminderEnabled: true,
                isAuthorized: true
            )
        ) {
            NotificationSettingsFeature()
        } withDependencies: {
            $0.notificationAdapter.scheduleDailyReminder = { h, m in
                savedHour.setValue(h)
                savedMinute.setValue(m)
            }
            $0.userSettingsAdapter.setInt = { val, key in
                if key.rawValue == SettingsKey<Int>.dailyReminderHour.rawValue { savedHour.setValue(val) }
                if key.rawValue == SettingsKey<Int>.dailyReminderMinute.rawValue { savedMinute.setValue(val) }
            }
        }

        let newDate = Calendar.current.date(from: DateComponents(hour: 8, minute: 30))!
        await store.send(.reminderDateChanged(newDate)) {
            $0.reminderDate = newDate
        }

        #expect(savedHour.value == 8)
        #expect(savedMinute.value == 30)
    }

    // MARK: - Budget Warning Toggle (Unauthorized)

    @Test("toggling budget warning on when unauthorized and denied shows banner")
    func testBudgetWarningToggleOnUnauthorizedDenied() async throws {
        let store = await TestStore(
            initialState: NotificationSettingsFeature.State(isAuthorized: false)
        ) {
            NotificationSettingsFeature()
        } withDependencies: {
            $0.notificationAdapter.requestAuthorization = { false }
            $0.userSettingsAdapter.setBool = { _, _ in }
            $0.userSettingsAdapter.setInt = { _, _ in }
        }

        await store.send(.budgetWarningToggled(true))
        await store.receive(\.permissionDenied) {
            $0.showPermissionDeniedBanner = true
        }
    }

    // MARK: - Recurring Management Integration

    @Test(".task forwards recurringManagement(.task) and reaches stable state")
    func taskForwardsToRecurringManagement() async {
        let store = await TestStore(initialState: NotificationSettingsFeature.State()) {
            NotificationSettingsFeature()
        } withDependencies: {
            $0.notificationAdapter.isAuthorized = { false }
            $0.userSettingsAdapter.bool = { $0.defaultValue }
            $0.userSettingsAdapter.int = { $0.defaultValue }
            $0.planningClient.warningEnabled = { false }
            $0.planningClient.warningThreshold = { 80 }
            $0.recurringTransactionClient.fetchAll = { [] }
        }
        await store.send(.task)
        await store.skipReceivedActions()
    }

    @Test("recurringManagement state is default-initialized with empty items")
    func recurringManagementStateIsEmbedded() {
        let state = NotificationSettingsFeature.State()
        #expect(state.recurringManagement.items.isEmpty)
    }

    // MARK: - Budget Warning Threshold

    @Test("warningThresholdChanged persists without triggering notification")
    func testWarningThresholdChanged() async throws {
        let persistedThreshold: LockIsolated<Int?> = LockIsolated(nil)
        let warningFired: LockIsolated<Bool> = LockIsolated(false)

        let store = await TestStore(
            initialState: NotificationSettingsFeature.State(budgetWarningEnabled: true)
        ) {
            NotificationSettingsFeature()
        } withDependencies: {
            $0.planningClient.setWarningThreshold = { val in persistedThreshold.setValue(val) }
            $0.notificationAdapter.sendBudgetWarning = { _, _, _ in warningFired.setValue(true) }
        }

        await store.send(.warningThresholdChanged(70)) {
            $0.warningThreshold = 70
        }

        #expect(persistedThreshold.value == 70)
        #expect(warningFired.value == false)
    }
}
