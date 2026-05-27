import Foundation
import Testing
import Dependencies
import Domain
@testable import WatchFeatures

@Suite("WatchCategoryClient Tests")
struct WatchCategoryClientTests {

    private func makeCache(with categories: [Domain.Category]) -> WatchCacheStore {
        let suite = "WatchCategoryClientTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let store = WatchCacheStore(defaults: defaults)
        store.save(WatchContextSnapshot(
            categories: categories, accounts: [], defaultAccountId: UUID(),
            todayTotal: 0, todayCount: 0, monthBudgetProgress: nil,
            snapshotAt: Date()
        ))
        return store
    }

    @Test("fetchAll returns the categories from the cached snapshot")
    func fetchAllReturnsCachedCategories() async throws {
        let category = Domain.Category(
            id: UUID(), name: "Food", icon: "fork.knife",
            color: "#FF9500", type: .expense, sortOrder: 0, isDefault: true
        )
        let cache = makeCache(with: [category])
        let client = CategoryClient.watchLive(cache: cache)

        let categories = try await client.fetchAll()
        #expect(categories == [category])
    }

    @Test("fetchByType(.expense) filters out non-expense categories")
    func fetchExpenseFiltersIncomeCategories() async throws {
        let expense = Domain.Category(
            id: UUID(), name: "Food", icon: "fork.knife",
            color: "#FF9500", type: .expense, sortOrder: 0, isDefault: true
        )
        let income = Domain.Category(
            id: UUID(), name: "Salary", icon: "dollarsign.circle",
            color: "#34C759", type: .income, sortOrder: 0, isDefault: true
        )
        let cache = makeCache(with: [expense, income])
        let client = CategoryClient.watchLive(cache: cache)

        let filtered = try await client.fetchByType(.expense)
        #expect(filtered == [expense])
    }

    @Test("fetchAll returns empty when cache has no snapshot")
    func fetchAllEmptyWhenCacheEmpty() async throws {
        let suite = "WatchCategoryClientTests.Empty.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let cache = WatchCacheStore(defaults: defaults)
        let client = CategoryClient.watchLive(cache: cache)

        let categories = try await client.fetchAll()
        #expect(categories.isEmpty)
    }
}
