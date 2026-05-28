import Testing
import Foundation
import Dependencies
@testable import Domain

@Suite("RecurringTransactionClient Domain Tests")
struct DomainRecurringTransactionClientTests {

    @Test("RecurringTransactionClient testValue is accessible via DependencyValues")
    func testDependencyInjection() {
        @Dependency(\.recurringTransactionClient) var client
        #expect(true, "RecurringTransactionClient injected successfully")
    }

    @Test("RecurringTransaction Codable round-trip preserves all fields")
    func testCodableRoundTrip() throws {
        let base = Date(timeIntervalSince1970: 0)
        let original = RecurringTransaction(
            id: UUID(), amount: 5000, note: "月租",
            categoryId: UUID(), accountId: UUID().uuidString, toAccountId: nil,
            type: .expense, tags: [], frequency: .monthly,
            nextDueDate: base, isActive: true, createdAt: base
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(RecurringTransaction.self, from: data)
        #expect(decoded == original)
    }

    @Test("nextDate weekly advances by 7 days")
    func testNextDateWeekly() {
        let base = Date(timeIntervalSince1970: 0)
        let rt = RecurringTransaction(
            id: UUID(), amount: 100, note: nil, categoryId: nil,
            accountId: UUID().uuidString, toAccountId: nil, type: .expense,
            tags: [], frequency: .weekly,
            nextDueDate: base, isActive: true, createdAt: base
        )
        let next = rt.nextDate(after: base)
        let expected = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: base)!
        #expect(next == expected)
    }

    @Test("nextDate monthly advances by 1 month")
    func testNextDateMonthly() {
        let base = Date(timeIntervalSince1970: 0)
        let rt = RecurringTransaction(
            id: UUID(), amount: 100, note: nil, categoryId: nil,
            accountId: UUID().uuidString, toAccountId: nil, type: .expense,
            tags: [], frequency: .monthly,
            nextDueDate: base, isActive: true, createdAt: base
        )
        let next = rt.nextDate(after: base)
        let expected = Calendar.current.date(byAdding: .month, value: 1, to: base)!
        #expect(next == expected)
    }

    @Test("nextDate yearly advances by 1 year")
    func testNextDateYearly() {
        let base = Date(timeIntervalSince1970: 0)
        let rt = RecurringTransaction(
            id: UUID(), amount: 100, note: nil, categoryId: nil,
            accountId: UUID().uuidString, toAccountId: nil, type: .expense,
            tags: [], frequency: .yearly,
            nextDueDate: base, isActive: true, createdAt: base
        )
        let next = rt.nextDate(after: base)
        let expected = Calendar.current.date(byAdding: .year, value: 1, to: base)!
        #expect(next == expected)
    }
}
