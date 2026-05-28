import Foundation
import Testing
import Domain
@testable import WatchFeatures

@Suite("WatchAccountClient Tests")
struct WatchAccountClientTests {

    private func makeCache(with accounts: [Account]) -> WatchCacheStore {
        let suite = "WatchAccountClientTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let store = WatchCacheStore(defaults: defaults)
        store.save(WatchContextSnapshot(
            categories: [], accounts: accounts, defaultAccountId: accounts.first?.id ?? UUID(),
            todayTotal: 0, todayCount: 0, monthBudgetProgress: nil,
            snapshotAt: Date()
        ))
        return store
    }

    @Test("fetchActive returns the accounts from the cached snapshot")
    func fetchActiveReturnsCachedAccounts() async throws {
        let cash = Account(
            id: UUID(), name: "Cash", type: .cash, icon: "banknote",
            color: "#34C759", sortOrder: 0, isArchived: false,
            createdAt: Date(timeIntervalSince1970: 0)
        )
        let cache = makeCache(with: [cash])
        let client = AccountClient.watchLive(cache: cache)

        let accounts = try await client.fetchActive()
        #expect(accounts == [cash])
    }

    @Test("fetchActive returns empty when cache is empty")
    func fetchActiveEmptyWhenCacheEmpty() async throws {
        let suite = "WatchAccountClientTests.Empty.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let cache = WatchCacheStore(defaults: defaults)
        let client = AccountClient.watchLive(cache: cache)

        let accounts = try await client.fetchActive()
        #expect(accounts.isEmpty)
    }
}
