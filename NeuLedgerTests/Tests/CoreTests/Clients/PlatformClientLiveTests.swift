import Testing
import SwiftData
import Foundation
import Dependencies
import Domain
@testable import Core

/// Live tests for `PlatformClient` — link routing (migrated from
/// `DeeplinkClientTests`), the recurring-confirmation resolution against an
/// in-memory store, and the preference / sync-flag round-trips lifted from
/// the former `AppEnvironmentUseCase` and `CloudSyncUseCase`.
@Suite("PlatformClient Live Tests")
struct PlatformClientLiveTests {

    /// Fresh in-memory container holding the recurring-transaction schema.
    private func freshContainer() throws -> ModelContainer {
        let schema = Schema([
            SDTransaction.self,
            SDAccount.self,
            SDCategory.self,
            SDBudget.self,
            SDTag.self,
            SDRecurringTransaction.self,
            SDCarrier.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    /// An in-memory `UserSettingsAdapter` backed by a locked box so
    /// preference setters/getters round-trip across String/Bool/Int/Date.
    private final class SettingsBox: @unchecked Sendable {
        private let lock = NSLock()
        private var bools: [String: Bool] = [:]
        private var ints: [String: Int] = [:]
        private var strings: [String: String] = [:]
        private var dates: [String: Date?] = [:]
        func getBool(_ k: String, _ f: Bool) -> Bool { lock.lock(); defer { lock.unlock() }; return bools[k] ?? f }
        func setBool(_ v: Bool, _ k: String) { lock.lock(); defer { lock.unlock() }; bools[k] = v }
        func getInt(_ k: String, _ f: Int) -> Int { lock.lock(); defer { lock.unlock() }; return ints[k] ?? f }
        func setInt(_ v: Int, _ k: String) { lock.lock(); defer { lock.unlock() }; ints[k] = v }
        func getString(_ k: String, _ f: String) -> String { lock.lock(); defer { lock.unlock() }; return strings[k] ?? f }
        func setString(_ v: String, _ k: String) { lock.lock(); defer { lock.unlock() }; strings[k] = v }
        func getDate(_ k: String, _ f: Date?) -> Date? { lock.lock(); defer { lock.unlock() }; return dates[k] ?? f }
        func setDate(_ v: Date?, _ k: String) { lock.lock(); defer { lock.unlock() }; dates[k] = v }
    }

    private func inMemorySettings(_ box: SettingsBox) -> UserSettingsAdapter {
        var adapter = UserSettingsAdapter.testValue
        adapter.bool = { box.getBool($0.rawValue, $0.defaultValue) }
        adapter.setBool = { box.setBool($0, $1.rawValue) }
        adapter.int = { box.getInt($0.rawValue, $0.defaultValue) }
        adapter.setInt = { box.setInt($0, $1.rawValue) }
        adapter.string = { box.getString($0.rawValue, $0.defaultValue) }
        adapter.setString = { box.setString($0, $1.rawValue) }
        adapter.date = { box.getDate($0.rawValue, $0.defaultValue) }
        adapter.setDate = { box.setDate($0, $1.rawValue) }
        return adapter
    }

    private func sut(
        container: ModelContainer? = nil,
        settings: UserSettingsAdapter? = nil,
        watch: WatchBridgeAdapter? = nil
    ) -> PlatformClient {
        withDependencies {
            if let container { $0.modelContainer = container }
            if let settings { $0.userSettingsAdapter = settings }
            if let watch { $0.watchBridgeAdapter = watch }
        } operation: {
            PlatformClient.liveValue
        }
    }

    // MARK: - Routing (migrated from DeeplinkClientTests)

    @Test("parseLink returns .carrierManagement for neuledger://carrier-management")
    func parseCarrierManagementHost() async throws {
        let client = sut()
        let url = URL(string: "neuledger://carrier-management")!
        let result = try await client.parseLink(url)
        #expect(result == .carrierManagement)
    }

    @Test("parseLink returns .none for unknown neuledger host")
    func parseUnknownHost() async throws {
        let client = sut()
        let url = URL(string: "neuledger://something-else")!
        let result = try await client.parseLink(url)
        #expect(result == .none)
    }

    @Test("parseLink returns .none for non-neuledger scheme")
    func parseForeignScheme() async throws {
        let client = sut()
        let url = URL(string: "https://example.com/carrier-management")!
        let result = try await client.parseLink(url)
        #expect(result == .none)
    }

    // MARK: - canSkipOnboarding

    @Test("canSkipOnboarding returns true when hasCompletedOnboarding flag is true")
    func canSkipWhenOnboardingCompleted() async throws {
        let box = SettingsBox()
        box.setBool(true, SettingsKey<Bool>.hasCompletedOnboarding.rawValue)
        let client = sut(settings: inMemorySettings(box))
        let result = try await client.canSkipOnboarding()
        #expect(result == true)
    }

    @Test("canSkipOnboarding returns false when hasCompletedOnboarding flag is false")
    func cannotSkipWhenOnboardingIncomplete() async throws {
        let box = SettingsBox()
        let client = sut(settings: inMemorySettings(box))
        let result = try await client.canSkipOnboarding()
        #expect(result == false)
    }

    // MARK: - resolveRecurringConfirmation

    @Test("resolveRecurringConfirmation returns .recurringConfirmation for an existing template")
    func resolveExistingRecurring() async throws {
        let container = try freshContainer()
        let store = withDependencies {
            $0.modelContainer = container
        } operation: {
            RecurringTransactionStore()
        }
        let template = RecurringTransaction(
            id: UUID(),
            amount: 100,
            note: "Rent",
            categoryId: nil,
            accountId: UUID().uuidString,
            toAccountId: nil,
            type: .expense,
            tags: [],
            frequency: .monthly,
            nextDueDate: Date(),
            isActive: true,
            createdAt: Date()
        )
        try await store.add(template)

        let client = sut(container: container)
        let result = try await client.resolveRecurringConfirmation(template.id)
        #expect(result == .recurringConfirmation(template))
    }

    @Test("resolveRecurringConfirmation returns .none for an unknown id")
    func resolveUnknownRecurring() async throws {
        let container = try freshContainer()
        let client = sut(container: container)
        let result = try await client.resolveRecurringConfirmation(UUID())
        #expect(result == .none)
    }

    // MARK: - Preferences round-trips

    @Test("setAccessoryMode then accessoryMode reads back the same value")
    func accessoryModeRoundTrip() async throws {
        let box = SettingsBox()
        let client = sut(settings: inMemorySettings(box))
        #expect(client.accessoryMode() == .add) // default
        client.setAccessoryMode(.ai)
        #expect(client.accessoryMode() == .ai)
    }

    @Test("setReminderTime then reminderTime reads back the same value")
    func reminderTimeRoundTrip() async throws {
        let box = SettingsBox()
        let client = sut(settings: inMemorySettings(box))
        #expect(client.reminderTime() == ReminderTime(hour: 21, minute: 0)) // default
        client.setReminderTime(ReminderTime(hour: 8, minute: 30))
        #expect(client.reminderTime() == ReminderTime(hour: 8, minute: 30))
    }

    @Test("setDailyReminderEnabled then dailyReminderEnabled reads back the same value")
    func dailyReminderEnabledRoundTrip() async throws {
        let box = SettingsBox()
        let client = sut(settings: inMemorySettings(box))
        #expect(client.dailyReminderEnabled() == false) // default
        client.setDailyReminderEnabled(true)
        #expect(client.dailyReminderEnabled() == true)
    }

    @Test("markOnboardingComplete flips hasCompletedOnboarding to true")
    func markOnboardingCompleteRoundTrip() async throws {
        let box = SettingsBox()
        let client = sut(settings: inMemorySettings(box))
        #expect(client.hasCompletedOnboarding() == false) // default
        client.markOnboardingComplete()
        #expect(client.hasCompletedOnboarding() == true)
    }

    @Test("setShowAccessoryBar then showAccessoryBar reads back the same value")
    func showAccessoryBarRoundTrip() async throws {
        let box = SettingsBox()
        let client = sut(settings: inMemorySettings(box))
        #expect(client.showAccessoryBar() == true) // default
        client.setShowAccessoryBar(false)
        #expect(client.showAccessoryBar() == false)
    }

    // MARK: - Watch

    @Test("watchPaired / watchAppInstalled forward to watchBridgeAdapter")
    func watchPairingForwards() async throws {
        var watch = WatchBridgeAdapter.testValue
        watch.isPaired = { true }
        watch.isWatchAppInstalled = { true }
        let client = sut(watch: watch)
        #expect(client.watchPaired() == true)
        #expect(client.watchAppInstalled() == true)
    }

    @Test("watchPaired / watchAppInstalled report false when no watch is paired")
    func watchPairingDefaultsFalse() async throws {
        var watch = WatchBridgeAdapter.testValue
        watch.isPaired = { false }
        watch.isWatchAppInstalled = { false }
        let client = sut(watch: watch)
        #expect(client.watchPaired() == false)
        #expect(client.watchAppInstalled() == false)
    }

    @Test("setWatchDefaultAccountId then watchDefaultAccountId reads back the same id")
    func watchDefaultAccountIdRoundTrip() async throws {
        let box = SettingsBox()
        let client = sut(settings: inMemorySettings(box))
        #expect(client.watchDefaultAccountId() == nil) // default
        let id: Account.ID = "33333333-3333-3333-3333-333333333333"
        client.setWatchDefaultAccountId(id)
        #expect(client.watchDefaultAccountId() == id)
    }

    @Test("setWatchDefaultAccountId(nil) clears the override back to nil")
    func watchDefaultAccountIdClears() async throws {
        let box = SettingsBox()
        let client = sut(settings: inMemorySettings(box))
        client.setWatchDefaultAccountId("33333333-3333-3333-3333-333333333333")
        #expect(client.watchDefaultAccountId() != nil)
        client.setWatchDefaultAccountId(nil)
        #expect(client.watchDefaultAccountId() == nil)
    }

    // MARK: - Sync flags

    @Test("syncEnabled reflects the isSyncEnabled flag")
    func syncEnabledReflectsFlag() async throws {
        let box = SettingsBox()
        let client = sut(settings: inMemorySettings(box))
        #expect(client.syncEnabled() == false) // default
        box.setBool(true, SettingsKey<Bool>.isSyncEnabled.rawValue)
        #expect(client.syncEnabled() == true)
    }

    @Test("lastSyncedAt reflects the stored date")
    func lastSyncedAtReflectsStoredDate() async throws {
        let box = SettingsBox()
        let client = sut(settings: inMemorySettings(box))
        #expect(client.lastSyncedAt() == nil) // default
        let stamp = Date(timeIntervalSince1970: 1_700_000_000)
        box.setDate(stamp, SettingsKey<Date?>.lastSyncedAt.rawValue)
        #expect(client.lastSyncedAt() == stamp)
    }

    // MARK: - testValue

    @Test("testValue is accessible via DependencyValues")
    func testValueRegistered() {
        withDependencies {
            $0.platformClient = .testValue
        } operation: {
            @Dependency(\.platformClient) var client
            _ = client
        }
    }
}
