import Testing
import SwiftData
import Foundation
import Domain
@testable import Core

@Suite("SDCategory PersistentDomainModel")
struct SDCategoryMappingTests {
    let container: ModelContainer
    let context: ModelContext

    init() throws {
        let schema = Schema([SDCategory.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        self.container = try ModelContainer(for: schema, configurations: [configuration])
        self.context = ModelContext(container)
    }

    @Test("applyChanges updates every mutable scalar field, preserves id")
    func testApplyChanges() throws {
        let originalId = UUID()
        let original = Domain.Category(
            id: originalId,
            name: "Old",
            icon: "old.icon",
            color: "#000000",
            type: .expense,
            sortOrder: 0,
            isDefault: false
        )
        let sd = SDCategory.from(original, context: context)
        try context.save()

        let edited = Domain.Category(
            id: originalId,
            name: "New",
            icon: "new.icon",
            color: "#FFFFFF",
            type: .income,
            sortOrder: 9,
            isDefault: true
        )
        sd.applyChanges(from: edited, context: context)
        try context.save()

        #expect(sd.id == originalId)
        #expect(sd.name == "New")
        #expect(sd.icon == "new.icon")
        #expect(sd.color == "#FFFFFF")
        #expect(sd.type == TransactionType.income.rawValue)
        #expect(sd.sortOrder == 9)
        #expect(sd.isDefault == true)
    }

    @Test("idPredicate matches only the given id")
    func testIdPredicate() throws {
        let a = Domain.Category(name: "A", icon: "", color: "#000", type: .expense)
        let b = Domain.Category(name: "B", icon: "", color: "#000", type: .income)
        SDCategory.from(a, context: context)
        SDCategory.from(b, context: context)
        try context.save()

        let matches = try context.fetch(
            FetchDescriptor<SDCategory>(predicate: SDCategory.idPredicate(a.id))
        )
        #expect(matches.count == 1)
        #expect(matches.first?.id == a.id)
    }
}
