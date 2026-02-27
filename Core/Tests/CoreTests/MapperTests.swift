import Testing
import SwiftData
import Foundation
import Domain
@testable import Core

@Suite("Mapper Tests")
struct MapperTests {
    var container: ModelContainer
    var context: ModelContext

    init() throws {
        let schema = Schema([
            SDTransaction.self,
            SDAccount.self,
            SDCategory.self,
            SDBudget.self,
            SDTag.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        self.container = try ModelContainer(for: schema, configurations: [configuration])
        self.context = ModelContext(container)
    }

    @Test("Account mapping round-trip")
    func testAccountMappingRoundTrip() throws {
        // Arrange
        let original = Account(
            id: UUID(),
            name: "Test Bank",
            type: .bank,
            icon: "building.columns",
            color: "#0000FF",
            sortOrder: 1,
            isArchived: false,
            createdAt: Date()
        )

        // Act (Domain -> SD)
        let sdModel = SDAccount.from(original, context: context)
        
        // Assert (SD -> Domain)
        let mappedBack = sdModel.toDomain()
        
        #expect(original.id == mappedBack.id)
        #expect(original.name == mappedBack.name)
        #expect(original.type == mappedBack.type)
        #expect(original.icon == mappedBack.icon)
        #expect(original.color == mappedBack.color)
        #expect(original.sortOrder == mappedBack.sortOrder)
        #expect(original.isArchived == mappedBack.isArchived)
        #expect(original.createdAt == mappedBack.createdAt)
    }

    @Test("Category mapping round-trip")
    func testCategoryMappingRoundTrip() throws {
        let original = Domain.Category(
            id: UUID(),
            name: "Food",
            icon: "fork.knife",
            color: "#FF0000",
            type: .expense,
            sortOrder: 0,
            isDefault: true
        )

        let sdModel = SDCategory.from(original, context: context)
        let mappedBack = sdModel.toDomain()

        #expect(original.id == mappedBack.id)
        #expect(original.name == mappedBack.name)
        #expect(original.type == mappedBack.type)
        #expect(original.isDefault == mappedBack.isDefault)
    }

    @Test("Tag mapping round-trip")
    func testTagMappingRoundTrip() throws {
        let original = Tag(
            id: UUID(),
            name: "Vacation",
            color: "#00FF00"
        )

        let sdModel = SDTag.from(original, context: context)
        let mappedBack = sdModel.toDomain()

        #expect(original.id == mappedBack.id)
        #expect(original.name == mappedBack.name)
        #expect(original.color == mappedBack.color)
    }

    @Test("Budget mapping round-trip")
    func testBudgetMappingRoundTrip() throws {
        let original = Budget(
            id: UUID(),
            name: "Monthly Dining",
            amount: 500,
            categoryId: UUID(),
            period: .monthly,
            startDate: Date(),
            isActive: true
        )

        let sdModel = SDBudget.from(original, context: context)
        let mappedBack = sdModel.toDomain()

        #expect(original.id == mappedBack.id)
        #expect(original.name == mappedBack.name)
        #expect(original.amount == mappedBack.amount)
        #expect(original.period == mappedBack.period)
    }

    @Test("Transaction mapping round-trip with tags")
    func testTransactionMappingRoundTripWithTags() throws {
        let tag1 = Tag(id: UUID(), name: "Travel", color: "#FFFFFF")
        let tag2 = Tag(id: UUID(), name: "Food", color: "#000000")
        
        let original = Transaction(
            id: UUID(),
            amount: 150.5,
            date: Date(),
            note: "Dinner in Paris",
            categoryId: UUID(),
            accountId: UUID(),
            toAccountId: nil,
            type: .expense,
            tags: [tag1, tag2],
            aiSuggested: true,
            createdAt: Date(),
            updatedAt: Date()
        )

        let sdModel = SDTransaction.from(original, context: context)
        try context.save() // Save to ensure relationships are realized

        let mappedBack = sdModel.toDomain()

        #expect(original.id == mappedBack.id)
        #expect(original.amount == mappedBack.amount)
        #expect(original.note == mappedBack.note)
        #expect(original.type == mappedBack.type)
        #expect(original.aiSuggested == mappedBack.aiSuggested)
        
        // Tags order isn't guaranteed in Many-to-Many relationships, so we sort them by ID for comparison
        let originalSortedTags = original.tags.sorted(by: { $0.id.uuidString < $1.id.uuidString })
        let mappedSortedTags = mappedBack.tags.sorted(by: { $0.id.uuidString < $1.id.uuidString })
        
        #expect(originalSortedTags.count == mappedSortedTags.count)
        if originalSortedTags.count == mappedSortedTags.count {
            for i in 0..<originalSortedTags.count {
                #expect(originalSortedTags[i].id == mappedSortedTags[i].id)
                #expect(originalSortedTags[i].name == mappedSortedTags[i].name)
            }
        }
    }
}
