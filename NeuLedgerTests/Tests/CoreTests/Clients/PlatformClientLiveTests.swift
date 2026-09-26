import Testing
import SwiftData
import Foundation
import Dependencies
import ConcurrencyExtras
import Domain
@testable import Core

/// Live tests for `PlatformClient` — link routing (migrated from
/// `DeeplinkClientTests`), the recurring-confirmation resolution against an
/// in-memory store, and the preference / sync-flag round-trips lifted from
/// the former `AppEnvironmentUseCase` and `CloudSyncUseCase`.
///
/// No `.serialized` needed: every test in this suite (including the
/// `seedIfNeeded` coverage for spec A1 — see the comment above that test)
/// works against a freshly created in-memory `ModelContainer` scoped to that
/// single test, never `PersistenceBootstrap.container` (the process-wide
/// live container). An earlier revision of this suite briefly called the
/// real `wipeAllSyncData()`, which does mutate that global directly, and was
/// serialized for that reason; that call is gone, so the trait went with it.
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

    private static func watchAccount(
        id: String,
        sortOrder: Int,
        isArchived: Bool = false
    ) -> Account {
        Account(
            id: id,
            name: "Account \(sortOrder)",
            type: .cash,
            icon: "banknote",
            color: "#34C759",
            sortOrder: sortOrder,
            isArchived: isArchived,
            createdAt: Date(timeIntervalSince1970: 0)
        )
    }

    /// Runs `pushWatchContext` against a fresh in-memory store seeded with
    /// `accounts`, with `storedId` written as the Settings override, and
    /// returns the snapshot captured by the spy bridge (or `nil` when the
    /// client never pushed).
    private func pushWatchContext(
        storedId: Account.ID?,
        accounts: [Account]
    ) async throws -> WatchContextSnapshot? {
        let container = try freshContainer()
        let box = SettingsBox()
        if let storedId {
            box.setString(storedId, SettingsKey<String>.watchDefaultAccountId.rawValue)
        }
        let pushed = LockIsolated<WatchContextSnapshot?>(nil)
        var watch = WatchBridgeAdapter.testValue
        watch.pushContext = { snapshot in pushed.setValue(snapshot) }

        try await withDependencies {
            $0.modelContainer = container
            $0.userSettingsAdapter = inMemorySettings(box)
            $0.watchBridgeAdapter = watch
            $0.calendar = Calendar(identifier: .gregorian)
            $0.planningClient.listActive = { @Sendable in [] }
            $0.carrierClient.listAll = { @Sendable in [] }
        } operation: {
            let accountStore = AccountStore()
            for account in accounts { try await accountStore.add(account) }
            let client = PlatformClient.liveValue
            await client.pushWatchContext()
        }

        return pushed.value
    }

    @Test("pushWatchContext honors a stored override that points to a live account")
    func pushWatchContextHonorsLiveOverride() async throws {
        let snapshot = try await pushWatchContext(
            storedId: "card-id",
            accounts: [
                Self.watchAccount(id: "cash-id", sortOrder: 0),
                Self.watchAccount(id: "card-id", sortOrder: 1),
            ]
        )
        #expect(snapshot?.defaultAccountId == "card-id")
    }

    @Test("pushWatchContext falls back past a dead stored override to the first active account")
    func pushWatchContextValidatesDeadOverride() async throws {
        let snapshot = try await pushWatchContext(
            storedId: "card-id",
            accounts: [
                Self.watchAccount(id: "cash-id", sortOrder: 0),
                Self.watchAccount(id: "card-id", sortOrder: 1, isArchived: true),
            ]
        )
        #expect(snapshot?.defaultAccountId == "cash-id")
    }

    @Test("pushWatchContext pushes nothing when there is no active account")
    func pushWatchContextSkipsWithoutActiveAccounts() async throws {
        let snapshot = try await pushWatchContext(
            storedId: "gone-id",
            accounts: [
                Self.watchAccount(id: "old-id", sortOrder: 0, isArchived: true),
            ]
        )
        #expect(snapshot == nil)
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

    // MARK: - Re-seeding after a wipe (spec A1)
    //
    // 刻意的覆蓋缺口：這裡不測「呼叫真正的 `wipeAllSyncData()` 之後分類有沒有
    // 回來」那條端到端路徑，即使那正是這個 spec 要保證的行為。原因：
    // `wipeAllSyncData` 讀寫的是 `PersistenceBootstrap.container` ——
    // process-wide 的全域容器，指向 `storeURL`。而 `NeuLedgerTests` 的
    // `TEST_HOST` 是 `NeuLedger.app`，繼承它的 `group.com.drake.NeuLedger`
    // App Group 權限，所以那不是測試專用容器，是跟已安裝 App 共用的同一顆
    // `default.store`。呼叫真正的實作會把裝置上的交易、帳戶、分類、預算、
    // 標籤、週期範本、載具全部刪光，只留下重新種回的 14 筆分類——這是資料
    // 損毀等級的風險，且目前 `storeURL` 沒有測試環境可以導向暫存目錄的注入
    // 點，無法用 in-memory 容器規避。
    //
    // 這不是推測：帶端到端版本的 `testWipeReseedsDefaultCategories` 真的在模擬器
    // 上跑過並通過，也就是真正的 `wipeAllSyncData()` 確實對 `storeURL` 執行過一次
    // 全表刪除。沒有人在刪除前後比對那顆 store 的內容，所以「使用者資料被清空」
    // 是從程式碼路徑推出的後果，不是實測到的觀察值。
    //
    // 改為直接測 `seedIfNeeded(in:)` 本身：它的簽章吃外部傳入的
    // `ModelContext`，跟全域容器完全解耦，可以在一顆乾淨的 in-memory 容器上
    // 安全驗證「清空後重新種入 14 筆預設分類」這個行為。`wipeAllSyncData`
    // 裡那一行 `PersistenceBootstrap.seedIfNeeded(in: ModelContext(localContainer))`
    // 是否真的接上了，目前只能靠 code review 把關（follow-up：讓 `storeURL`
    // 在測試環境下可注入暫存路徑，屆時才補得出安全的端到端測試）。

    @Test("seedIfNeeded populates the default categories on an empty store")
    func testSeedIfNeededPopulatesDefaultCategoriesOnAnEmptyStore() async throws {
        let container = try freshContainer()
        let context = ModelContext(container)

        PersistenceBootstrap.seedIfNeeded(in: context)

        let categories = try await withDependencies {
            $0.modelContainer = container
        } operation: {
            try await CategoryStore().fetchAll()
        }
        #expect(categories.isEmpty == false, "seedIfNeeded 必須在空的 store 上種入預設分類")
        #expect(categories.contains { $0.isDefault })
        #expect(categories.count == 14, "14 筆預設分類（9 支出 + 5 收入）")
    }
}
