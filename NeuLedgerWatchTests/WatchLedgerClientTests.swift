import Foundation
import Testing
import Domain
import ConcurrencyExtras
@testable import WatchFeatures

/// 合併自已退役的 WatchAccountClientTests / WatchCategoryClientTests /
/// WatchTransactionClientTests（步驟 5d：三個 `.watchLive` split client
/// 收編為 `WatchLedgerClient`）。型別已修正為 `Account.ID == String`。
@Suite("WatchLedgerClient Tests")
struct WatchLedgerClientTests {

    final class FakeGateway: WatchDraftSender, @unchecked Sendable {
        let sent = LockIsolated<[TransactionDraft]>([])
        func send(draft: TransactionDraft) {
            sent.withValue { $0.append(draft) }
        }
    }

    private func makeCache(
        accounts: [Account] = [],
        categories: [Domain.Category] = [],
        suiteName: String = #function
    ) -> WatchCacheStore {
        let suite = "WatchLedgerClientTests.\(suiteName).\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let store = WatchCacheStore(defaults: defaults)
        store.save(WatchContextSnapshot(
            categories: categories, accounts: accounts,
            defaultAccountId: accounts.first?.id ?? "",
            todayTotal: 0, todayCount: 0, monthBudgetProgress: nil,
            snapshotAt: Date()
        ))
        return store
    }

    private func makeEmptyCache() -> WatchCacheStore {
        let suite = "WatchLedgerClientTests.Empty.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return WatchCacheStore(defaults: defaults)
    }

    // MARK: - activeAccounts（原 WatchAccountClientTests）

    @Test("activeAccounts returns the accounts from the cached snapshot")
    func activeAccountsReturnsCachedAccounts() async throws {
        let cash = Account(
            id: "acct-cash", name: "Cash", type: .cash, icon: "banknote",
            color: "#34C759", sortOrder: 0, isArchived: false,
            createdAt: Date(timeIntervalSince1970: 0)
        )
        let client = WatchLedgerClient.watchLive(
            cache: makeCache(accounts: [cash]), gateway: FakeGateway()
        )

        let accounts = try await client.activeAccounts()
        #expect(accounts == [cash])
    }

    @Test("activeAccounts returns empty when cache is empty")
    func activeAccountsEmptyWhenCacheEmpty() async throws {
        let client = WatchLedgerClient.watchLive(
            cache: makeEmptyCache(), gateway: FakeGateway()
        )

        let accounts = try await client.activeAccounts()
        #expect(accounts.isEmpty)
    }

    // MARK: - categories（原 WatchCategoryClientTests）

    @Test("categories(.expense) returns the expense categories from the cached snapshot")
    func categoriesReturnsCachedExpenseCategories() async throws {
        let category = Domain.Category(
            id: UUID(), name: "Food", icon: "fork.knife",
            color: "#FF9500", type: .expense, sortOrder: 0, isDefault: true
        )
        let client = WatchLedgerClient.watchLive(
            cache: makeCache(categories: [category]), gateway: FakeGateway()
        )

        let categories = try await client.categories(.expense)
        #expect(categories == [category])
    }

    @Test("categories(.expense) filters out non-expense categories")
    func categoriesFiltersIncomeCategories() async throws {
        let expense = Domain.Category(
            id: UUID(), name: "Food", icon: "fork.knife",
            color: "#FF9500", type: .expense, sortOrder: 0, isDefault: true
        )
        let income = Domain.Category(
            id: UUID(), name: "Salary", icon: "dollarsign.circle",
            color: "#34C759", type: .income, sortOrder: 0, isDefault: true
        )
        let client = WatchLedgerClient.watchLive(
            cache: makeCache(categories: [expense, income]), gateway: FakeGateway()
        )

        let filtered = try await client.categories(.expense)
        #expect(filtered == [expense])
    }

    @Test("categories returns empty when cache has no snapshot")
    func categoriesEmptyWhenCacheEmpty() async throws {
        let client = WatchLedgerClient.watchLive(
            cache: makeEmptyCache(), gateway: FakeGateway()
        )

        let categories = try await client.categories(.expense)
        #expect(categories.isEmpty)
    }

    // MARK: - record（原 WatchTransactionClientTests）

    @Test("record converts Transaction to TransactionDraft and forwards to the gateway")
    func recordForwardsToGateway() async throws {
        let gateway = FakeGateway()
        let client = WatchLedgerClient.watchLive(cache: makeEmptyCache(), gateway: gateway)

        let tx = Transaction(
            id: UUID(),
            amount: 250,
            date: Date(timeIntervalSince1970: 1_700_000_000),
            categoryId: UUID(),
            accountId: "acct-1",
            type: .expense
        )

        try await client.record(tx)

        let sent = gateway.sent.value
        #expect(sent.count == 1)
        #expect(sent.first?.id == tx.id)
        #expect(sent.first?.amount == 250)
        #expect(sent.first?.categoryId == tx.categoryId)
        #expect(sent.first?.accountId == tx.accountId)
    }

    @Test("record drops a transaction whose categoryId is nil")
    func recordDropsTransactionWithNilCategory() async throws {
        let gateway = FakeGateway()
        let client = WatchLedgerClient.watchLive(cache: makeEmptyCache(), gateway: gateway)

        let tx = Transaction(
            amount: 100,
            date: Date(),
            categoryId: nil,
            accountId: "acct-1",
            type: .expense
        )

        // Should not throw, just no-op.
        try await client.record(tx)
        #expect(gateway.sent.value.isEmpty)
    }
}
