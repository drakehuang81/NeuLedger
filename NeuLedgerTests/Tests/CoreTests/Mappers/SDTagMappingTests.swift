import Testing
import SwiftData
import Foundation
import Domain
@testable import Core

@Suite("SDTag PersistentDomainModel")
struct SDTagMappingTests {
    let container: ModelContainer
    let context: ModelContext

    init() throws {
        let schema = Schema([SDTag.self, SDTransaction.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        self.container = try ModelContainer(for: schema, configurations: [configuration])
        self.context = ModelContext(container)
    }

    @Test("prepareForDelete disassociates the tag from its inverse transactions")
    func testPrepareForDeleteDisassocs() throws {
        let tag = Tag(id: UUID(), name: "T", color: "#fff")
        let sdTag = SDTag.from(tag, context: context)
        let tx = Transaction(
            amount: 100,
            date: Date(),
            accountId: UUID(),
            type: .expense,
            tags: [tag]
        )
        let sdTx = SDTransaction.from(tx, context: context)
        try context.save()

        #expect((sdTag.transactions ?? []).count == 1)
        #expect((sdTx.tags ?? []).count == 1)

        sdTag.prepareForDelete()
        try context.save()

        #expect((sdTag.transactions ?? []).isEmpty)
        #expect((sdTx.tags ?? []).isEmpty)
    }

    @Test("applyChanges updates name and color, preserves id")
    func testApplyChanges() throws {
        let originalId = UUID()
        let original = Tag(id: originalId, name: "Old", color: "#000000")
        let sd = SDTag.from(original, context: context)
        try context.save()

        let edited = Tag(id: originalId, name: "New", color: "#FFFFFF")
        sd.applyChanges(from: edited, context: context)
        try context.save()

        #expect(sd.id == originalId)
        #expect(sd.name == "New")
        #expect(sd.color == "#FFFFFF")
    }

    @Test("idPredicate matches only the given id")
    func testIdPredicate() throws {
        let a = Tag(id: UUID(), name: "A", color: "#fff")
        let b = Tag(id: UUID(), name: "B", color: "#000")
        SDTag.from(a, context: context)
        SDTag.from(b, context: context)
        try context.save()

        let matches = try context.fetch(
            FetchDescriptor<SDTag>(predicate: SDTag.idPredicate(a.id))
        )
        #expect(matches.count == 1)
        #expect(matches.first?.id == a.id)
    }
}
