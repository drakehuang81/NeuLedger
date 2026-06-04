import Foundation
import Testing
import Dependencies
@testable import Domain

@Suite("PlatformClient Domain Tests")
struct PlatformClientTests {

    @Test("PlatformClient testValue is accessible via DependencyValues")
    func testDependencyKey() {
        @Dependency(\.platformClient) var client
        #expect(true, "PlatformClient injected successfully")
    }

    // MARK: - Preferences

    @Test("accessoryMode / setAccessoryMode mock override")
    func testAccessoryModeMock() {
        withDependencies {
            $0.platformClient.accessoryMode = { .ai }
            $0.platformClient.setAccessoryMode = { _ in }
        } operation: {
            @Dependency(\.platformClient) var client
            #expect(client.accessoryMode() == .ai)
            client.setAccessoryMode(.add)
        }
    }

    @Test("reminderTime / setReminderTime mock override")
    func testReminderTimeMock() {
        withDependencies {
            $0.platformClient.reminderTime = { ReminderTime(hour: 7, minute: 15) }
            $0.platformClient.setReminderTime = { _ in }
        } operation: {
            @Dependency(\.platformClient) var client
            #expect(client.reminderTime() == ReminderTime(hour: 7, minute: 15))
            client.setReminderTime(ReminderTime(hour: 9, minute: 0))
        }
    }

    @Test("dailyReminderEnabled / setDailyReminderEnabled mock override")
    func testDailyReminderEnabledMock() {
        withDependencies {
            $0.platformClient.dailyReminderEnabled = { true }
            $0.platformClient.setDailyReminderEnabled = { _ in }
        } operation: {
            @Dependency(\.platformClient) var client
            #expect(client.dailyReminderEnabled() == true)
            client.setDailyReminderEnabled(false)
        }
    }

    @Test("hasCompletedOnboarding / markOnboardingComplete mock override")
    func testOnboardingMock() {
        withDependencies {
            $0.platformClient.hasCompletedOnboarding = { true }
            $0.platformClient.markOnboardingComplete = { }
        } operation: {
            @Dependency(\.platformClient) var client
            #expect(client.hasCompletedOnboarding() == true)
            client.markOnboardingComplete()
        }
    }

    @Test("showAccessoryBar / setShowAccessoryBar mock override")
    func testShowAccessoryBarMock() {
        withDependencies {
            $0.platformClient.showAccessoryBar = { false }
            $0.platformClient.setShowAccessoryBar = { _ in }
        } operation: {
            @Dependency(\.platformClient) var client
            #expect(client.showAccessoryBar() == false)
            client.setShowAccessoryBar(true)
        }
    }

    // MARK: - Notification

    @Test("requestNotificationPermission mock override")
    func testRequestNotificationPermissionMock() async {
        await withDependencies {
            $0.platformClient.requestNotificationPermission = { true }
        } operation: {
            @Dependency(\.platformClient) var client
            let granted = await client.requestNotificationPermission()
            #expect(granted == true)
        }
    }

    @Test("notificationsAuthorized mock override")
    func testNotificationsAuthorizedMock() async {
        await withDependencies {
            $0.platformClient.notificationsAuthorized = { true }
        } operation: {
            @Dependency(\.platformClient) var client
            let authorized = await client.notificationsAuthorized()
            #expect(authorized == true)
        }
    }

    @Test("scheduleDailyReminder / cancelDailyReminder mock override")
    func testScheduleCancelDailyReminderMock() async throws {
        try await withDependencies {
            $0.platformClient.scheduleDailyReminder = { }
            $0.platformClient.cancelDailyReminder = { }
        } operation: {
            @Dependency(\.platformClient) var client
            try await client.scheduleDailyReminder()
            await client.cancelDailyReminder()
        }
    }

    @Test("pendingRecurringConfirmations mock override")
    func testPendingRecurringConfirmationsMock() async {
        let id = UUID()
        await withDependencies {
            $0.platformClient.pendingRecurringConfirmations = {
                let (stream, continuation) = AsyncStream<RecurringTransaction.ID>.makeStream()
                continuation.yield(id)
                continuation.finish()
                return stream
            }
        } operation: {
            @Dependency(\.platformClient) var client
            var received: [RecurringTransaction.ID] = []
            for await value in client.pendingRecurringConfirmations() {
                received.append(value)
            }
            #expect(received == [id])
        }
    }

    // MARK: - Sync

    @Test("syncAvailable / syncEnabled mock override")
    func testSyncFlagsMock() {
        withDependencies {
            $0.platformClient.syncAvailable = { true }
            $0.platformClient.syncEnabled = { true }
        } operation: {
            @Dependency(\.platformClient) var client
            #expect(client.syncAvailable() == true)
            #expect(client.syncEnabled() == true)
        }
    }

    @Test("lastSyncedAt mock override")
    func testLastSyncedAtMock() {
        let stamp = Date(timeIntervalSince1970: 1_700_000_000)
        withDependencies {
            $0.platformClient.lastSyncedAt = { stamp }
        } operation: {
            @Dependency(\.platformClient) var client
            #expect(client.lastSyncedAt() == stamp)
        }
    }

    @Test("enableSync mock override yields progress values")
    func testEnableSyncMock() async throws {
        try await withDependencies {
            $0.platformClient.enableSync = {
                AsyncThrowingStream { continuation in
                    continuation.yield(0.5)
                    continuation.yield(1.0)
                    continuation.finish()
                }
            }
        } operation: {
            @Dependency(\.platformClient) var client
            var values: [Double] = []
            for try await value in client.enableSync() {
                values.append(value)
            }
            #expect(values == [0.5, 1.0])
        }
    }

    @Test("requestSyncNow / wipeAllSyncData mock override")
    func testSyncActionsMock() async throws {
        try await withDependencies {
            $0.platformClient.requestSyncNow = { }
            $0.platformClient.wipeAllSyncData = { }
        } operation: {
            @Dependency(\.platformClient) var client
            try await client.requestSyncNow()
            try await client.wipeAllSyncData()
        }
    }

    // MARK: - Routing

    @Test("parseLink mock override")
    func testParseLinkMock() async throws {
        try await withDependencies {
            $0.platformClient.parseLink = { _ in .carrierManagement }
        } operation: {
            @Dependency(\.platformClient) var client
            let result = try await client.parseLink(URL(string: "neuledger://carrier-management")!)
            #expect(result == .carrierManagement)
        }
    }

    @Test("canSkipOnboarding mock override")
    func testCanSkipOnboardingMock() async throws {
        try await withDependencies {
            $0.platformClient.canSkipOnboarding = { true }
        } operation: {
            @Dependency(\.platformClient) var client
            let result = try await client.canSkipOnboarding()
            #expect(result == true)
        }
    }

    @Test("resolveRecurringConfirmation mock override")
    func testResolveRecurringConfirmationMock() async throws {
        try await withDependencies {
            $0.platformClient.resolveRecurringConfirmation = { _ in .main }
        } operation: {
            @Dependency(\.platformClient) var client
            let result = try await client.resolveRecurringConfirmation(UUID())
            #expect(result == .main)
        }
    }

    // MARK: - System

    @Test("openAppSettings mock override")
    func testOpenAppSettingsMock() {
        withDependencies {
            $0.platformClient.openAppSettings = { }
        } operation: {
            @Dependency(\.platformClient) var client
            client.openAppSettings()
        }
    }
}
