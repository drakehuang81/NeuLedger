import Testing
import SwiftData
import Foundation
import Domain
@testable import Core

@Suite("SDTransaction PersistentDomainModel")
struct SDTransactionMappingTests {
    let container: ModelContainer
    let context: ModelContext

    init() throws {
        let schema = Schema([SDTransaction.self, SDTag.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        self.container = try ModelContainer(for: schema, configurations: [configuration])
        self.context = ModelContext(container)
    }

    @Test("applyChanges updates every scalar field except id and createdAt")
    func testApplyChangesScalarFields() throws {
        let originalId = UUID()
        let originalCreatedAt = Date(timeIntervalSince1970: 1_000)
        let accountId = UUID().uuidString
        let original = Transaction(
            id: originalId,
            amount: 100,
            date: Date(timeIntervalSince1970: 1_500),
            note: "old",
            categoryId: nil,
            accountId: accountId,
            type: .expense,
            aiSuggested: false,
            createdAt: originalCreatedAt,
            updatedAt: originalCreatedAt
        )
        let sd = SDTransaction.from(original, context: context)
        try context.save()

        let newCategoryId = UUID()
        let newToAccountId = UUID().uuidString
        let newDate = Date(timeIntervalSince1970: 9_999)
        let edited = Transaction(
            id: originalId,
            amount: 250,
            date: newDate,
            note: "new note",
            categoryId: newCategoryId,
            accountId: accountId,
            toAccountId: newToAccountId,
            type: .income,
            aiSuggested: true,
            createdAt: originalCreatedAt,
            updatedAt: newDate
        )
        sd.applyChanges(from: edited, context: context)
        try context.save()

        #expect(sd.id == originalId)
        #expect(sd.createdAt == originalCreatedAt)
        #expect(sd.amount == 250)
        #expect(sd.note == "new note")
        #expect(sd.date == newDate)
        #expect(sd.categoryId == newCategoryId)
        #expect(sd.toAccountId == newToAccountId)
        #expect(sd.type == TransactionType.income.rawValue)
        #expect(sd.aiSuggested == true)
        #expect(sd.updatedAt == newDate)
    }

    @Test("applyChanges resolves tags through SDTag.resolve")
    func testApplyChangesResolvesTags() throws {
        let original = Transaction(
            amount: 100,
            date: Date(),
            accountId: UUID().uuidString,
            type: .expense
        )
        let sd = SDTransaction.from(original, context: context)
        try context.save()

        let tagA = Tag(id: UUID(), name: "A", color: "#fff")
        let tagB = Tag(id: UUID(), name: "B", color: "#000")
        let edited = Transaction(
            id: original.id,
            amount: original.amount,
            date: original.date,
            accountId: original.accountId,
            type: original.type,
            tags: [tagA, tagB],
            createdAt: original.createdAt,
            updatedAt: Date()
        )
        sd.applyChanges(from: edited, context: context)
        try context.save()

        let ids = Set((sd.tags ?? []).map(\.id))
        #expect(ids == Set([tagA.id, tagB.id]))
    }

    @Test("idPredicate matches only the given id")
    func testIdPredicate() throws {
        let a = Transaction(amount: 100, date: Date(), accountId: UUID().uuidString, type: .expense)
        let b = Transaction(amount: 200, date: Date(), accountId: UUID().uuidString, type: .income)
        SDTransaction.from(a, context: context)
        SDTransaction.from(b, context: context)
        try context.save()

        let descriptor = FetchDescriptor<SDTransaction>(predicate: SDTransaction.idPredicate(a.id))
        let matches = try context.fetch(descriptor)
        #expect(matches.count == 1)
        #expect(matches.first?.id == a.id)
    }

    @Test("the recurring source fields round-trip through the SwiftData model")
    func testRecurringSourceFieldsRoundTrip() throws {
        let templateId = UUID()
        let due = Date(timeIntervalSince1970: 1_767_139_200)
        let domain = Transaction(
            id: UUID(), amount: 18_000, date: due,
            note: "rent", categoryId: nil, accountId: UUID().uuidString,
            toAccountId: nil, type: .expense, tags: [],
            aiSuggested: false, createdAt: due, updatedAt: due,
            sourceTemplateId: templateId, sourcePeriodDueDate: due
        )
        let model = SDTransaction.from(domain, context: context)
        #expect(model.sourceTemplateId == templateId)
        #expect(model.sourcePeriodDueDate == due)

        let back = model.toDomain()
        #expect(back.sourceTemplateId == templateId)
        #expect(back.sourcePeriodDueDate == due)
    }

    @Test("a manually recorded transaction keeps both source fields nil")
    func testManualTransactionHasNoSource() throws {
        let domain = Transaction(
            amount: 120, date: Date(), accountId: UUID().uuidString, type: .expense
        )
        #expect(domain.sourceTemplateId == nil)
        #expect(domain.sourcePeriodDueDate == nil)

        let model = SDTransaction.from(domain, context: context)
        #expect(model.toDomain().sourceTemplateId == nil)
        #expect(model.toDomain().sourcePeriodDueDate == nil)
    }

    @Test("applyChanges carries the source fields")
    func testApplyChangesCarriesSource() throws {
        var domain = Transaction(
            amount: 1, date: Date(), accountId: UUID().uuidString, type: .expense
        )
        let model = SDTransaction.from(domain, context: context)

        let templateId = UUID()
        let due = Date(timeIntervalSince1970: 1_767_139_200)
        domain.sourceTemplateId = templateId
        domain.sourcePeriodDueDate = due
        model.applyChanges(from: domain, context: context)

        #expect(model.sourceTemplateId == templateId)
        #expect(model.sourcePeriodDueDate == due)
    }
}
