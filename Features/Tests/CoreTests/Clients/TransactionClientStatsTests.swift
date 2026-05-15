import Testing
import Foundation
import SwiftData
import Dependencies
@testable import Core
import Domain

@Suite("TransactionClient.statsSnapshot")
struct TransactionClientStatsTests {

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

    @Test("Computes today + week + savings %")
    func test() async throws {
        let (dbc, ctx) = try makeTestDatabaseClient()
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let acctId = UUID()

        // Today: expense 200
        ctx.insert(SDTransaction(
            id: UUID(), amount: 200, date: today, note: "",
            categoryId: nil, accountId: acctId, toAccountId: nil,
            type: TransactionType.expense.rawValue,
            aiSuggested: false, createdAt: today, updatedAt: today
        ))
        // 3 days ago: expense 100
        let d3 = cal.date(byAdding: .day, value: -3, to: today)!
        ctx.insert(SDTransaction(
            id: UUID(), amount: 100, date: d3, note: "",
            categoryId: nil, accountId: acctId, toAccountId: nil,
            type: TransactionType.expense.rawValue,
            aiSuggested: false, createdAt: d3, updatedAt: d3
        ))
        // 3 days ago: income 1000
        ctx.insert(SDTransaction(
            id: UUID(), amount: 1000, date: d3, note: "",
            categoryId: nil, accountId: acctId, toAccountId: nil,
            type: TransactionType.income.rawValue,
            aiSuggested: false, createdAt: d3, updatedAt: d3
        ))
        try ctx.save()

        let snap = try await withDependencies {
            $0.databaseClient = dbc
        } operation: {
            try await TransactionClient.liveValue.statsSnapshot()
        }
        #expect(snap.today == 200)
        #expect(snap.week == 300)
        // income 1000, expense 300, savings = (1000 - 300) / 1000 = 0.7
        #expect(abs(snap.savingsPercentage - 0.7) < 0.001)
    }

    @Test("Zero income → zero savings")
    func testNoIncome() async throws {
        let (dbc, ctx) = try makeTestDatabaseClient()
        let today = Calendar.current.startOfDay(for: Date())
        ctx.insert(SDTransaction(
            id: UUID(), amount: 50, date: today, note: "",
            categoryId: nil, accountId: UUID(), toAccountId: nil,
            type: TransactionType.expense.rawValue,
            aiSuggested: false, createdAt: today, updatedAt: today
        ))
        try ctx.save()

        let snap = try await withDependencies {
            $0.databaseClient = dbc
        } operation: {
            try await TransactionClient.liveValue.statsSnapshot()
        }
        #expect(snap.today == 50)
        #expect(snap.week == 50)
        #expect(snap.savingsPercentage == 0)
    }
}
