import Foundation
import Testing
import SwiftData
import Dependencies
import Domain
@testable import Core

@Suite("WatchContextBuilder Tests")
struct WatchContextBuilderTests {

    /// Builds a fresh in-memory container and seeds the supplied domain
    /// values through `SwiftDataStore`, so `WatchContextBuilder.build`
    /// (which now reads SwiftData directly) sees them. Returns the
    /// container so the caller can inject it via `$0.modelContainer`.
    private func makeSeededContainer(
        categories: [Domain.Category] = [],
        accounts: [Account] = [],
        transactions: [Transaction] = []
    ) async throws -> ModelContainer {
        let schema = Schema([
            SDTransaction.self,
            SDAccount.self,
            SDCategory.self,
            SDBudget.self,
            SDTag.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])

        try await withDependencies {
            $0.modelContainer = container
        } operation: {
            let categoryStore = SwiftDataStore<Domain.Category, SDCategory>()
            let accountStore = SwiftDataStore<Account, SDAccount>()
            let transactionStore = SwiftDataStore<Transaction, SDTransaction>()
            for category in categories { try await categoryStore.add(category) }
            for account in accounts { try await accountStore.add(account) }
            for transaction in transactions { try await transactionStore.add(transaction) }
        }

        return container
    }

    @Test("Snapshot aggregates only today's expenses, not income or other days")
    func aggregatesTodaysExpensesOnly() async throws {
        let accountId = UUID().uuidString
        let category = Category(
            id: UUID(),
            name: "Food",
            icon: "fork.knife",
            color: "#FF9500",
            type: .expense,
            sortOrder: 0,
            isDefault: true
        )
        let account = Account(
            id: accountId,
            name: "Cash",
            type: .cash,
            icon: "banknote",
            color: "#34C759",
            sortOrder: 0,
            isArchived: false,
            createdAt: Date(timeIntervalSince1970: 0)
        )

        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let yesterday = now.addingTimeInterval(-60 * 60 * 24)
        let earlierToday = now.addingTimeInterval(-3600)

        let txns: [Transaction] = [
            Transaction(amount: 300, date: now, accountId: accountId, type: .expense),
            Transaction(amount: 180, date: earlierToday, accountId: accountId, type: .expense),
            Transaction(amount: 500, date: yesterday, accountId: accountId, type: .expense),
            Transaction(amount: 1000, date: now, accountId: accountId, type: .income),
        ]

        let container = try await makeSeededContainer(
            categories: [category],
            accounts: [account],
            transactions: txns
        )

        let snapshot = try await withDependencies {
            $0.calendar = Calendar(identifier: .gregorian)
            $0.modelContainer = container
            $0.planningClient.listActive = { @Sendable in [] }
        } operation: {
            try await WatchContextBuilder.build(now: now, defaultAccountId: accountId)
        }

        #expect(snapshot.todayTotal == 480)
        #expect(snapshot.todayCount == 2)
        #expect(snapshot.categories.count == 1)
        #expect(snapshot.accounts.count == 1)
        #expect(snapshot.defaultAccountId == accountId)
        #expect(snapshot.monthBudgetProgress == nil)
    }

    @Test("monthBudgetProgress is nil when no overall monthly budget is active")
    func monthBudgetProgressNilWhenNoBudgetActive() async throws {
        let container = try await makeSeededContainer()

        let snapshot = try await withDependencies {
            $0.calendar = Calendar(identifier: .gregorian)
            $0.modelContainer = container
            $0.planningClient.listActive = { @Sendable in [] }
        } operation: {
            try await WatchContextBuilder.build(now: Date(), defaultAccountId: UUID().uuidString)
        }

        #expect(snapshot.monthBudgetProgress == nil)
    }
}
