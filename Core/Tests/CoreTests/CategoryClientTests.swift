import Testing
import SwiftData
import Foundation
import Dependencies
@testable import Core
import Domain

@Suite("CategoryClient Integration Tests")
struct CategoryClientTests {
    var container: ModelContainer
    var context: ModelContext
    
    // System under test
    var sut: CategoryClient

    init() throws {
        let schema = Schema([
            SDTransaction.self,
            SDAccount.self,
            SDCategory.self,
            SDBudget.self,
            SDTag.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let _container = try ModelContainer(for: schema, configurations: [configuration])
        self.container = _container
        self.context = ModelContext(_container)
        
        let testDatabaseClient = DatabaseClient(modelContainer: { _container })
        
        // Inject test DatabaseClient into CategoryClient
        self.sut = withDependencies {
            $0.databaseClient = testDatabaseClient
        } operation: {
            CategoryClient.liveValue
        }
    }

    @Test("Add category")
    func testAddCategory() async throws {
        // Arrange
        let newCategory = Category(
            id: UUID(),
            name: "Dining",
            icon: "fork.knife",
            color: "#FFFFFF",
            type: .expense,
            sortOrder: 0,
            isDefault: false
        )
        
        // Act
        try await sut.add(newCategory)
        
        // Assert
        let categories = try await sut.fetchAll()
        #expect(categories.count == 1)
        #expect(categories.first?.id == newCategory.id)
    }

    @Test("Fetch categories by type")
    func testFetchByType() async throws {
        // Arrange
        let expenseCat = Category(
            id: UUID(), name: "Dining", icon: "app", color: "#FFF", type: .expense, sortOrder: 0, isDefault: false
        )
        let incomeCat = Category(
            id: UUID(), name: "Salary", icon: "app", color: "#FFF", type: .income, sortOrder: 0, isDefault: false
        )
        try await sut.add(expenseCat)
        try await sut.add(incomeCat)
        
        // Act
        let expenseCategories = try await sut.fetchByType(.expense)
        let incomeCategories = try await sut.fetchByType(.income)
        
        // Assert
        #expect(expenseCategories.count == 1)
        #expect(expenseCategories.first?.id == expenseCat.id)
        #expect(incomeCategories.count == 1)
        #expect(incomeCategories.first?.id == incomeCat.id)
    }
    
    @Test("Update category updates specific fields")
    func testUpdateCategory() async throws {
        // Arrange
        let cat = Category(
            id: UUID(), name: "Dining", icon: "app", color: "#FFF", type: .expense, sortOrder: 0, isDefault: false
        )
        try await sut.add(cat)
        
        // Act
        let updatedCat = Category(
            id: cat.id, name: "Food & Dining", icon: "test", color: "#000", type: .expense, sortOrder: 1, isDefault: false
        )
        try await sut.update(updatedCat)
        
        // Assert
        let fetchedCat = try await sut.fetchAll().first
        #expect(fetchedCat?.name == "Food & Dining")
        #expect(fetchedCat?.icon == "test")
        #expect(fetchedCat?.color == "#000")
        #expect(fetchedCat?.sortOrder == 1)
    }
    
    @Test("Delete default category should fail with operationDenied error")
    func testDeleteDefaultCategoryDenied() async {
        // Arrange
        let defaultCat = Category(
            id: UUID(), name: "Dining", icon: "app", color: "#FFF", type: .expense, sortOrder: 0, isDefault: true
        )
        do {
            try await sut.add(defaultCat)
        } catch {
            Issue.record("Failed to add test category")
        }
        
        // Act & Assert
        do {
            try await sut.delete(defaultCat.id)
            Issue.record("Should have thrown operationDenied")
        } catch CoreError.operationDenied(let message) {
            #expect(message.contains("default"))
        } catch {
            Issue.record("Threw wrong error: \(error)")
        }
        
        // Ensure category still exists
        let remaining = try? await sut.fetchAll()
        #expect(remaining?.count == 1)
    }
    
    @Test("Delete custom category succeeds")
    func testDeleteCustomCategory() async throws {
        // Arrange
        let customCat = Category(
            id: UUID(), name: "Gaming", icon: "app", color: "#FFF", type: .expense, sortOrder: 0, isDefault: false
        )
        try await sut.add(customCat)
        
        // Act
        try await sut.delete(customCat.id)
        
        // Assert
        let remaining = try await sut.fetchAll()
        #expect(remaining.isEmpty)
    }
}
