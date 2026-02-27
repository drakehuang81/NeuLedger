import Foundation
import Testing
@testable import Domain

@Suite("Category Tests")
struct CategoryTests {
    @Test("Category Initialization and Equatable")
    func testInitializationAndEquatable() {
        let id = UUID()
        let cat1 = Category(id: id, name: "Food", icon: "fork.knife", color: "#FF0000", type: .expense)
        let cat2 = Category(id: id, name: "Food", icon: "fork.knife", color: "#FF0000", type: .expense)
        let cat3 = Category(name: "Salary", icon: "banknote", color: "#00FF00", type: .income)
        
        #expect(cat1 == cat2)
        #expect(cat1 != cat3)
        #expect(cat1.sortOrder == 0)
        #expect(cat1.isDefault == false)
    }

    @Test("Category Hashable")
    func testHashable() {
        let id = UUID()
        let cat1 = Category(id: id, name: "Food", icon: "fork.knife", color: "#FF0000", type: .expense)
        let cat2 = Category(id: id, name: "Food", icon: "fork.knife", color: "#FF0000", type: .expense)
        
        #expect(cat1.hashValue == cat2.hashValue)
    }

    @Test("Category Codable round-trip")
    func testCodable() throws {
        let cat = Category(name: "Food", icon: "fork.knife", color: "#FF0000", type: .expense)
        
        let data = try JSONEncoder().encode(cat)
        let decoded = try JSONDecoder().decode(Category.self, from: data)
        #expect(decoded == cat)
    }
}
