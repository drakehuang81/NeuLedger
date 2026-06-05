import Testing
import SwiftData
import Foundation
import Domain
@testable import Core

@Suite("SDRecurringTransaction PersistentDomainModel")
struct SDRecurringTransactionMappingTests {
    let container: ModelContainer
    let context: ModelContext

    init() throws {
        let schema = Schema([SDRecurringTransaction.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        self.container = try ModelContainer(for: schema, configurations: [configuration])
        self.context = ModelContext(container)
    }

    @Test("applyChanges updates every mutable scalar field, preserves id and createdAt")
    func testApplyChanges() throws {
        let originalId = UUID()
        let originalCreatedAt = Date(timeIntervalSince1970: 1_000)
        let originalAccountId = UUID().uuidString
        let original = RecurringTransaction(
            id: originalId,
            amount: 100,
            note: "old",
            categoryId: nil,
            accountId: originalAccountId,
            toAccountId: nil,
            type: .expense,
            tags: [],
            frequency: .monthly,
            nextDueDate: Date(timeIntervalSince1970: 1_500),
            isActive: false,
            createdAt: originalCreatedAt
        )
        let sd = SDRecurringTransaction.from(original, context: context)
        try context.save()

        let newCategoryId = UUID()
        let newAccountId = UUID().uuidString
        let newToAccountId = UUID().uuidString
        let newNextDueDate = Date(timeIntervalSince1970: 9_999)
        let tagA = Tag(id: UUID(), name: "A", color: "#fff")
        let edited = RecurringTransaction(
            id: originalId,
            amount: 250,
            note: "new",
            categoryId: newCategoryId,
            accountId: newAccountId,
            toAccountId: newToAccountId,
            type: .transfer,
            tags: [tagA],
            frequency: .weekly,
            nextDueDate: newNextDueDate,
            isActive: true,
            createdAt: originalCreatedAt
        )
        sd.applyChanges(from: edited, context: context)
        try context.save()

        #expect(sd.id == originalId)
        #expect(sd.createdAt == originalCreatedAt)
        #expect(sd.amount == 250)
        #expect(sd.note == "new")
        #expect(sd.categoryId == newCategoryId)
        #expect(sd.accountId == newAccountId)
        #expect(sd.toAccountId == newToAccountId)
        #expect(sd.typeRaw == TransactionType.transfer.rawValue)
        #expect(sd.tagIds == [tagA.id])
        #expect(sd.frequencyRaw == BudgetPeriod.weekly.rawValue)
        #expect(sd.nextDueDate == newNextDueDate)
        #expect(sd.isActive == true)
    }

    @Test("idPredicate matches only the given id")
    func testIdPredicate() throws {
        let a = RecurringTransaction(
            id: UUID(), amount: 100, note: nil,
            categoryId: nil, accountId: UUID().uuidString, toAccountId: nil,
            type: .expense, tags: [], frequency: .monthly,
            nextDueDate: Date(), isActive: true, createdAt: Date()
        )
        let b = RecurringTransaction(
            id: UUID(), amount: 200, note: nil,
            categoryId: nil, accountId: UUID().uuidString, toAccountId: nil,
            type: .income, tags: [], frequency: .yearly,
            nextDueDate: Date(), isActive: true, createdAt: Date()
        )
        SDRecurringTransaction.from(a, context: context)
        SDRecurringTransaction.from(b, context: context)
        try context.save()

        let matches = try context.fetch(
            FetchDescriptor<SDRecurringTransaction>(predicate: SDRecurringTransaction.idPredicate(a.id))
        )
        #expect(matches.count == 1)
        #expect(matches.first?.id == a.id)
    }
}
