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
            $0.platformClient.dailyReminderEnabled = { true }
            $0.platformClient.reminderTime = { ReminderTime(hour: 8, minute: 0) }
            $0.planningClient.warningEnabled = { false }
            $0.planningClient.warningThreshold = { 80 }
            $0.platformClient.notificationsAuthorized = { true }
            $0.ledgerClient.listRecurring = { [] }
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
            $0.platformClient.setReminderTime = { time in
                scheduledHour.setValue(time.hour)
                scheduledMinute.setValue(time.minute)
            }
            $0.platformClient.scheduleDailyReminder = { }
            $0.platformClient.setDailyReminderEnabled = { val in persistedEnabled.setValue(val) }
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
            $0.platformClient.cancelDailyReminder = { cancelCalled.setValue(true) }
            $0.platformClient.setDailyReminderEnabled = { _ in }
        }

        await store.send(.dailyReminderToggled(false)) {
            $0.dailyReminderEnabled = false
        }

        #expect(cancelCalled.value == true)
    }

    // MARK: - Permission Denied

    @Test("toggling on when unauthorized requests permission; denial shows banner")
    func testToggleOnUnauthorizedDenied() async throws {
        let setEnabledCalled: LockIsolated<Bool> = LockIsolated(false)

        let store = await TestStore(
            initialState: NotificationSettingsFeature.State(isAuthorized: false)
        ) {
            NotificationSettingsFeature()
        } withDependencies: {
            $0.platformClient.requestNotificationPermission = { false }  // denied
            $0.platformClient.scheduleDailyReminder = { }
            $0.platformClient.setDailyReminderEnabled = { _ in setEnabledCalled.setValue(true) }
        }

        await store.send(.dailyReminderToggled(true))
        await store.receive(\.permissionDenied) {
            $0.showPermissionDeniedBanner = true
        }

        #expect(setEnabledCalled.value == false, "Should not persist when permission denied")
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
            $0.platformClient.notificationsAuthorized = { true }  // user granted permission in Settings
            $0.platformClient.dailyReminderEnabled = { false }
            $0.platformClient.reminderTime = { ReminderTime(hour: 21, minute: 0) }
            $0.planningClient.warningEnabled = { false }
            $0.planningClient.warningThreshold = { 80 }
            $0.ledgerClient.listRecurring = { [] }
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
            $0.platformClient.scheduleDailyReminder = { }
            $0.platformClient.setReminderTime = { time in
                savedHour.setValue(time.hour)
                savedMinute.setValue(time.minute)
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
            $0.platformClient.requestNotificationPermission = { false }
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
            $0.platformClient.notificationsAuthorized = { false }
            $0.platformClient.dailyReminderEnabled = { false }
            $0.platformClient.reminderTime = { ReminderTime(hour: 21, minute: 0) }
            $0.planningClient.warningEnabled = { false }
            $0.planningClient.warningThreshold = { 80 }
            $0.ledgerClient.listRecurring = { [] }
        }
        await MainActor.run { store.exhaustivity = .off }
        await store.send(.task)
        // 測試主旨：.task 必須轉發給內嵌的 RecurringManagement（其餘載入動作不在斷言範圍）
        await store.receive(\.recurringManagement.task)
        await store.finish()
    }

    @Test("recurringManagement state is default-initialized with empty items")
    func recurringManagementStateIsEmbedded() {
        let state = NotificationSettingsFeature.State()
        #expect(state.recurringManagement.items.isEmpty)
    }

    // MARK: - dailyReminder 未授權→授予→重試

    @Test("dailyReminderToggled 未授權、授予 → authorizationStatusLoaded + 重試 → setReminderTime + scheduleDailyReminder 被呼叫")
    func testDailyReminderUnauthorizedGrantedRetry() async throws {
        let setReminderTimeCalled: LockIsolated<Int> = LockIsolated(0)
        let scheduleDailyReminderCalled: LockIsolated<Int> = LockIsolated(0)
        let setEnabledCalled: LockIsolated<Bool?> = LockIsolated(nil)

        let store = await TestStore(
            initialState: NotificationSettingsFeature.State(isAuthorized: false)
        ) {
            NotificationSettingsFeature()
        } withDependencies: {
            $0.platformClient.requestNotificationPermission = { true } // 授予
            $0.platformClient.setReminderTime = { _ in
                setReminderTimeCalled.withValue { $0 += 1 }
            }
            $0.platformClient.scheduleDailyReminder = {
                scheduleDailyReminderCalled.withValue { $0 += 1 }
            }
            $0.platformClient.setDailyReminderEnabled = { val in
                setEnabledCalled.setValue(val)
            }
        }

        // 第一次 send：未授權，觸發請求
        await store.send(.dailyReminderToggled(true))

        // effect 授予後送 authorizationStatusLoaded(true)
        await store.receive(\.authorizationStatusLoaded) {
            $0.isAuthorized = true
            $0.showPermissionDeniedBanner = false
        }

        // 接著自動重試送 dailyReminderToggled(true)，這次已授權，走正規路徑
        await store.receive(.dailyReminderToggled(true)) {
            $0.dailyReminderEnabled = true
        }

        #expect(setReminderTimeCalled.value == 1, "setReminderTime 應被呼叫一次（重試時）")
        #expect(scheduleDailyReminderCalled.value == 1, "scheduleDailyReminder 應被呼叫一次")
        #expect(setEnabledCalled.value == true, "setDailyReminderEnabled(true) 應被呼叫")
    }

    // MARK: - budgetWarning 未授權→授予→重試

    @Test("budgetWarningToggled 未授權、授予 → authorizationStatusLoaded + 重試 → setWarningEnabled(true) 被呼叫")
    func testBudgetWarningUnauthorizedGrantedRetry() async throws {
        let setWarningEnabledCalled: LockIsolated<Bool?> = LockIsolated(nil)

        let store = await TestStore(
            initialState: NotificationSettingsFeature.State(isAuthorized: false)
        ) {
            NotificationSettingsFeature()
        } withDependencies: {
            $0.platformClient.requestNotificationPermission = { true } // 授予
            $0.planningClient.setWarningEnabled = { val in
                setWarningEnabledCalled.setValue(val)
            }
        }

        await store.send(.budgetWarningToggled(true))

        await store.receive(\.authorizationStatusLoaded) {
            $0.isAuthorized = true
            $0.showPermissionDeniedBanner = false
        }

        await store.receive(.budgetWarningToggled(true)) {
            $0.budgetWarningEnabled = true
        }

        #expect(setWarningEnabledCalled.value == true, "setWarningEnabled(true) 應被呼叫（重試後已授權路徑）")
    }

    // MARK: - openSystemSettingsTapped

    @Test("openSystemSettingsTapped 呼叫 platformClient.openAppSettings")
    func testOpenSystemSettingsTapped() async throws {
        let openAppSettingsCalled: LockIsolated<Int> = LockIsolated(0)

        let store = await TestStore(
            initialState: NotificationSettingsFeature.State()
        ) {
            NotificationSettingsFeature()
        } withDependencies: {
            $0.platformClient.openAppSettings = {
                openAppSettingsCalled.withValue { $0 += 1 }
            }
        }

        await store.send(.openSystemSettingsTapped)

        #expect(openAppSettingsCalled.value == 1, "openAppSettings 應被呼叫一次")
    }

    // MARK: - Budget Warning Threshold

    @Test("warningThresholdChanged persists without triggering notification")
    func testWarningThresholdChanged() async throws {
        let persistedThreshold: LockIsolated<Int?> = LockIsolated(nil)

        let store = await TestStore(
            initialState: NotificationSettingsFeature.State(budgetWarningEnabled: true)
        ) {
            NotificationSettingsFeature()
        } withDependencies: {
            $0.planningClient.setWarningThreshold = { val in persistedThreshold.setValue(val) }
        }

        await store.send(.warningThresholdChanged(70)) {
            $0.warningThreshold = 70
        }

        #expect(persistedThreshold.value == 70)
    }
}
