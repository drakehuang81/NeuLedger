import Foundation
import Testing
@testable import Domain

@Suite("Transaction Tests")
struct TransactionTests {
    @Test("Transaction default values")
    func testDefaultValues() {
        let now = Date()
        let tx = Transaction(amount: 100, date: now, accountId: UUID(), type: .expense, createdAt: now, updatedAt: now)

        #expect(tx.note == nil)
        #expect(tx.categoryId == nil)
        #expect(tx.toAccountId == nil)
        #expect(tx.tags.isEmpty)
        #expect(tx.aiSuggested == false)
    }

    @Test("Transaction custom values")
    func testCustomValues() {
        let accountId = UUID()
        let categoryId = UUID()
        let now = Date()

        let tx = Transaction(
            amount: 200,
            date: now,
            note: "Lunch",
            categoryId: categoryId,
            accountId: accountId,
            type: .income,
            tags: [Domain.Tag(name: "TestTag")],
            aiSuggested: true,
            createdAt: now,
            updatedAt: now
        )

        #expect(tx.amount == 200)
        #expect(tx.note == "Lunch")
        #expect(tx.categoryId == categoryId)
        #expect(tx.type == .income)
        #expect(tx.aiSuggested == true)
        #expect(tx.tags.count == 1)
    }

    @Test("Transaction Equatable")
    func testEquatable() {
        let id = UUID()
        let now = Date()
        let accountId = UUID()

        let tx1 = Transaction(id: id, amount: 100, date: now, accountId: accountId, type: .expense, createdAt: now, updatedAt: now)
        let tx2 = Transaction(id: id, amount: 100, date: now, accountId: accountId, type: .expense, createdAt: now, updatedAt: now)
        let tx3 = Transaction(id: UUID(), amount: 100, date: now, accountId: accountId, type: .expense, createdAt: now, updatedAt: now)

        #expect(tx1 == tx2)
        #expect(tx1 != tx3)
    }

    @Test("Transaction Hashable")
    func testHashable() {
        let id = UUID()
        let now = Date()
        let accountId = UUID()

        let tx1 = Transaction(id: id, amount: 100, date: now, accountId: accountId, type: .expense, createdAt: now, updatedAt: now)
        let tx2 = Transaction(id: id, amount: 100, date: now, accountId: accountId, type: .expense, createdAt: now, updatedAt: now)
        let tx3 = Transaction(id: UUID(), amount: 100, date: now, accountId: accountId, type: .expense, createdAt: now, updatedAt: now)

        #expect(tx1.hashValue == tx2.hashValue)
        #expect(tx1.hashValue != tx3.hashValue)

        var set = Set<Transaction>()
        set.insert(tx1)
        #expect(set.contains(tx2))
        #expect(!set.contains(tx3))
    }

    @Test("Transaction Codable round-trip")
    func testCodable() throws {
        let now = Date()
        let tx = Transaction(amount: 100, date: now, accountId: UUID(), type: .expense, createdAt: now, updatedAt: now)

        let data = try JSONEncoder().encode(tx)
        let decoded = try JSONDecoder().decode(Transaction.self, from: data)
        #expect(decoded == tx)
    }

    @Test("Transaction Transfer has toAccountId")
    func testTransferTransaction() {
        let sourceId = UUID()
        let destId = UUID()
        let now = Date()

        let tx = Transaction(
            amount: 500,
            date: now,
            accountId: sourceId,
            toAccountId: destId,
            type: .transfer,
            createdAt: now,
            updatedAt: now
        )

        #expect(tx.type == .transfer)
        #expect(tx.toAccountId == destId)
        #expect(tx.categoryId == nil)
    }
}
