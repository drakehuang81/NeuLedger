import Testing
import Foundation
import SwiftData
import Dependencies
@testable import Core
import Domain

@Suite("TransactionClient.weeklySpending")
struct TransactionClientWeeklyTests {

    private func makeTestDatabaseClient() throws -> (DatabaseClient, ModelContext) {
        let schema = Schema([
            SDTransaction.self,
            SDAccount.self,
            SDCategory.self,
            SDBudget.self,
            SDTag.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let dbc = DatabaseClient(modelContainer: { container })
        let ctx = ModelContext(container)
        return (dbc, ctx)
    }

    @Test("Returns N entries summed per day, oldest to newest")
    func testWeeklyCounts() async throws {
        let (dbc, ctx) = try makeTestDatabaseClient()

        let acc = SDAccount(
            id: UUID(),
            name: "Test",
            type: AccountType.cash.rawValue,
            icon: "banknote",
            color: "#000",
            sortOrder: 0,
            isArchived: false,
            createdAt: Date()
        )
        ctx.insert(acc)

        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        for i in 0 ..< 7 {
            let date = cal.date(byAdding: .day, value: -i, to: today)!
            let tx = SDTransaction(
                id: UUID(),
                amount: Decimal(100 * (i + 1)),
                date: date,
                note: "",
                categoryId: nil,
                accountId: acc.id,
                toAccountId: nil,
                type: TransactionType.expense.rawValue,
                aiSuggested: false,
                createdAt: date,
                updatedAt: date
            )
            ctx.insert(tx)
        }
        try ctx.save()

        let result = try await withDependencies {
            $0.databaseClient = dbc
            $0.modelContainer = dbc.modelContainer()
        } operation: {
            try await TransactionClient.liveValue.weeklySpending(nil, 7)
        }

        #expect(result.count == 7)
        #expect(result[6] == 100)   // today
        #expect(result[0] == 700)   // 6 days ago
    }

    @Test("Filters by accountID when provided")
    func testFilteredByAccount() async throws {
        let (dbc, ctx) = try makeTestDatabaseClient()

        let a = SDAccount(id: UUID(), name: "A", type: AccountType.cash.rawValue, icon: "", color: "#000", sortOrder: 0, isArchived: false, createdAt: Date())
        let b = SDAccount(id: UUID(), name: "B", type: AccountType.bank.rawValue, icon: "", color: "#000", sortOrder: 1, isArchived: false, createdAt: Date())
        ctx.insert(a)
        ctx.insert(b)

        let today = Calendar.current.startOfDay(for: Date())
        ctx.insert(SDTransaction(
            id: UUID(), amount: 200, date: today, note: "", categoryId: nil,
            accountId: a.id, toAccountId: nil, type: TransactionType.expense.rawValue,
            aiSuggested: false, createdAt: today, updatedAt: today
        ))
        ctx.insert(SDTransaction(
            id: UUID(), amount: 500, date: today, note: "", categoryId: nil,
            accountId: b.id, toAccountId: nil, type: TransactionType.expense.rawValue,
            aiSuggested: false, createdAt: today, updatedAt: today
        ))
        try ctx.save()

        let result = try await withDependencies {
            $0.databaseClient = dbc
            $0.modelContainer = dbc.modelContainer()
        } operation: {
            try await TransactionClient.liveValue.weeklySpending(a.id, 7)
        }
        #expect(result.count == 7)
        #expect(result[6] == 200)
    }

    @Test("Ignores income/transfer entries")
    func testIgnoresNonExpense() async throws {
        let (dbc, ctx) = try makeTestDatabaseClient()
        let acc = SDAccount(id: UUID(), name: "X", type: AccountType.cash.rawValue, icon: "", color: "#000", sortOrder: 0, isArchived: false, createdAt: Date())
        ctx.insert(acc)
        let today = Calendar.current.startOfDay(for: Date())
        ctx.insert(SDTransaction(
            id: UUID(), amount: 999, date: today, note: "", categoryId: nil,
            accountId: acc.id, toAccountId: nil, type: TransactionType.income.rawValue,
            aiSuggested: false, createdAt: today, updatedAt: today
        ))
        try ctx.save()
        let result = try await withDependencies {
            $0.databaseClient = dbc
            $0.modelContainer = dbc.modelContainer()
        } operation: {
            try await TransactionClient.liveValue.weeklySpending(nil, 7)
        }
        #expect(result.allSatisfy { $0 == 0 })
    }
}
