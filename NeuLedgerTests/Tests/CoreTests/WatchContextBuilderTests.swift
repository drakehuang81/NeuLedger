import Foundation
import Testing
import Dependencies
import Domain
@testable import Core

@Suite("WatchContextBuilder Tests")
struct WatchContextBuilderTests {

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

        let snapshot = try await withDependencies {
            $0.calendar = Calendar(identifier: .gregorian)
            $0.transactionClient.fetchAll = { @Sendable in txns }
            $0.categoryClient.fetchAll = { @Sendable in [category] }
            $0.accountClient.fetchActive = { @Sendable in [account] }
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
        let snapshot = try await withDependencies {
            $0.calendar = Calendar(identifier: .gregorian)
            $0.transactionClient.fetchAll = { @Sendable in [] }
            $0.categoryClient.fetchAll = { @Sendable in [] }
            $0.accountClient.fetchActive = { @Sendable in [] }
            $0.planningClient.listActive = { @Sendable in [] }
        } operation: {
            try await WatchContextBuilder.build(now: Date(), defaultAccountId: UUID().uuidString)
        }

        #expect(snapshot.monthBudgetProgress == nil)
    }
}
