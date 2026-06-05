import Testing
import SwiftData
import Foundation
import Domain
@testable import Core

@Suite("SDAccount PersistentDomainModel")
struct SDAccountMappingTests {
    let container: ModelContainer
    let context: ModelContext

    init() throws {
        let schema = Schema([SDAccount.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        self.container = try ModelContainer(for: schema, configurations: [configuration])
        self.context = ModelContext(container)
    }

    @Test("applyChanges updates every mutable scalar field, preserves id and createdAt")
    func testApplyChanges() throws {
        let originalId = UUID().uuidString
        let originalCreatedAt = Date(timeIntervalSince1970: 1_000)
        let original = Account(
            id: originalId,
            name: "Old",
            type: .cash,
            icon: "old.icon",
            color: "#000000",
            sortOrder: 0,
            isArchived: false,
            createdAt: originalCreatedAt
        )
        let sd = SDAccount.from(original, context: context)
        try context.save()

        let edited = Account(
            id: originalId,
            name: "New",
            type: .bank,
            icon: "new.icon",
            color: "#FFFFFF",
            sortOrder: 5,
            isArchived: true,
            createdAt: originalCreatedAt
        )
        sd.applyChanges(from: edited, context: context)
        try context.save()

        #expect(sd.id == originalId)
        #expect(sd.createdAt == originalCreatedAt)
        #expect(sd.name == "New")
        #expect(sd.type == AccountType.bank.rawValue)
        #expect(sd.icon == "new.icon")
        #expect(sd.color == "#FFFFFF")
        #expect(sd.sortOrder == 5)
        #expect(sd.isArchived == true)
    }

    @Test("idPredicate matches only the given id")
    func testIdPredicate() throws {
        let a = Account(name: "A", type: .cash, icon: "", color: "#000")
        let b = Account(name: "B", type: .bank, icon: "", color: "#000")
        SDAccount.from(a, context: context)
        SDAccount.from(b, context: context)
        try context.save()

        let matches = try context.fetch(
            FetchDescriptor<SDAccount>(predicate: SDAccount.idPredicate(a.id))
        )
        #expect(matches.count == 1)
        #expect(matches.first?.id == a.id)
    }
}
