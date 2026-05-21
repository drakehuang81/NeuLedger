import Testing
import SwiftData
import Foundation
import Domain
@testable import Core

@Suite("SDBudget PersistentDomainModel")
struct SDBudgetMappingTests {
    let container: ModelContainer
    let context: ModelContext

    init() throws {
        let schema = Schema([SDBudget.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        self.container = try ModelContainer(for: schema, configurations: [configuration])
        self.context = ModelContext(container)
    }

    @Test("applyChanges updates every mutable scalar field, preserves id")
    func testApplyChanges() throws {
        let originalId = UUID()
        let original = Budget(
            id: originalId,
            name: "Old",
            amount: 1_000,
            categoryId: nil,
            period: .monthly,
            startDate: Date(timeIntervalSince1970: 1_000),
            isActive: false
        )
        let sd = SDBudget.from(original, context: context)
        try context.save()

        let newCategoryId = UUID()
        let newStartDate = Date(timeIntervalSince1970: 9_999)
        let edited = Budget(
            id: originalId,
            name: "New",
            amount: 5_555,
            categoryId: newCategoryId,
            period: .yearly,
            startDate: newStartDate,
            isActive: true
        )
        sd.applyChanges(from: edited, context: context)
        try context.save()

        #expect(sd.id == originalId)
        #expect(sd.name == "New")
        #expect(sd.amount == 5_555)
        #expect(sd.categoryId == newCategoryId)
        #expect(sd.period == BudgetPeriod.yearly.rawValue)
        #expect(sd.startDate == newStartDate)
        #expect(sd.isActive == true)
    }

    @Test("idPredicate matches only the given id")
    func testIdPredicate() throws {
        let a = Budget(name: "A", amount: 100, period: .monthly, startDate: Date())
        let b = Budget(name: "B", amount: 200, period: .weekly, startDate: Date())
        SDBudget.from(a, context: context)
        SDBudget.from(b, context: context)
        try context.save()

        let matches = try context.fetch(
            FetchDescriptor<SDBudget>(predicate: SDBudget.idPredicate(a.id))
        )
        #expect(matches.count == 1)
        #expect(matches.first?.id == a.id)
    }
}
