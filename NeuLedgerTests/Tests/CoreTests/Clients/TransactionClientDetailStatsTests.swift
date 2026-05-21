import Dependencies
import Foundation
import SwiftData
import Testing
import Domain
@testable import Core

@Suite("TransactionAnalyticsKernel.detailStats Tests")
struct TransactionClientDetailStatsTests {

    private static func freshClient() -> DatabaseClient {
        return DatabaseClient.testValue
    }

    /// Convenience wrapper around `TransactionAnalyticsKernel.detailStats`
    /// — the kernel replaced `DatabaseClient.detailStats` in Phase 5.5 when
    /// analytics computation moved out of `DatabaseClient` so it could
    /// later be retired.
    private static func detailStats(for transaction: Transaction, on client: DatabaseClient) throws -> TransactionInsight {
        try TransactionAnalyticsKernel.detailStats(for: transaction, container: client.modelContainer())
    }

    /// Inserts a Domain `Transaction` into the client's container without going
    /// through DatabaseClient.add (which is being retired in Phase 1.6 of the
    /// architecture migration). Uses the SD mapper directly.
    private static func insert(_ transaction: Transaction, into client: DatabaseClient) throws {
        let ctx = ModelContext(client.modelContainer())
        SDTransaction.from(transaction, context: ctx)
        try ctx.save()
    }

    private static let accountID = UUID(uuidString: "11000000-0000-0000-0000-000000000001")!
    private static let categoryFood = UUID(uuidString: "33000000-0000-0000-0000-000000000001")!
    private static let categorySalary = UUID(uuidString: "33000000-0000-0000-0000-000000000002")!

    @Test("Expense returns expenseVsCategoryAvg with month total and count")
    func testExpenseStats() async throws {
        let client = Self.freshClient()
        let now = Date()
        let subject = Transaction(amount: 250, date: now, categoryId: Self.categoryFood, accountId: Self.accountID, type: .expense)
        let other = Transaction(amount: 150, date: now, categoryId: Self.categoryFood, accountId: Self.accountID, type: .expense)
        try Self.insert(subject, into: client)
        try Self.insert(other, into: client)

        let insight = try Self.detailStats(for: subject, on: client)

        guard case let .expenseVsCategoryAvg(_, avg, count, total) = insight.kind else {
            Issue.record("Expected expenseVsCategoryAvg, got \(insight.kind)")
            return
        }
        #expect(count == 2)
        #expect(total == 400)
        #expect(avg == 200)
    }

    @Test("Income returns incomeVsLast with monthly count")
    func testIncomeStats() async throws {
        let client = Self.freshClient()
        let now = Date()
        let prior = Transaction(amount: 48_000, date: Calendar.current.date(byAdding: .day, value: -2, to: now)!, categoryId: Self.categorySalary, accountId: Self.accountID, type: .income)
        let subject = Transaction(amount: 50_000, date: now, categoryId: Self.categorySalary, accountId: Self.accountID, type: .income)
        try Self.insert(prior, into: client)
        try Self.insert(subject, into: client)

        let insight = try Self.detailStats(for: subject, on: client)
        guard case let .incomeVsLast(percentDelta, lastAmount, monthlyCount, _) = insight.kind else {
            Issue.record("Expected incomeVsLast, got \(insight.kind)")
            return
        }
        #expect(lastAmount == 48_000)
        #expect(monthlyCount == 2)
        #expect(abs(percentDelta - ((50_000 - 48_000) / 48_000 * 100)) < 0.01)
    }

    @Test("Transfer returns transfer kind with monthly total")
    func testTransferStats() async throws {
        let client = Self.freshClient()
        let now = Date()
        let other = Transaction(amount: 2500, date: now, accountId: Self.accountID, toAccountId: UUID(), type: .transfer)
        let subject = Transaction(amount: 3000, date: now, accountId: Self.accountID, toAccountId: UUID(), type: .transfer)
        try Self.insert(other, into: client)
        try Self.insert(subject, into: client)

        let insight = try Self.detailStats(for: subject, on: client)
        guard case let .transfer(count, total) = insight.kind else {
            Issue.record("Expected transfer, got \(insight.kind)")
            return
        }
        #expect(count == 2)
        #expect(total == 5500)
    }

    @Test("Expense without category falls back")
    func testExpenseFallbackNoCategory() async throws {
        let client = Self.freshClient()
        let subject = Transaction(amount: 100, date: .now, categoryId: nil, accountId: Self.accountID, type: .expense)
        try Self.insert(subject, into: client)

        let insight = try Self.detailStats(for: subject, on: client)
        guard case let .fallback(count) = insight.kind else {
            Issue.record("Expected fallback, got \(insight.kind)")
            return
        }
        #expect(count == 1)
    }
}
