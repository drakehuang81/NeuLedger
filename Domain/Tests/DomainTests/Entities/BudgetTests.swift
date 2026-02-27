import Foundation
import Testing
@testable import Domain

@Suite("Budget Tests")
struct BudgetTests {
    @Test("Budget Initialization and Equatable")
    func testInitializationAndEquatable() {
        let id = UUID()
        let now = Date()
        let b1 = Budget(id: id, name: "Groceries", amount: 500, categoryId: UUID(), period: .monthly, startDate: now)
        let b2 = Budget(id: id, name: "Groceries", amount: 500, categoryId: b1.categoryId, period: .monthly, startDate: now)
        let b3 = Budget(name: "Total", amount: 2000, categoryId: nil, period: .monthly, startDate: now)
        
        #expect(b1 == b2)
        #expect(b1 != b3)
        #expect(b1.isActive == true)
    }

    @Test("Budget Hashable")
    func testHashable() {
        let id = UUID()
        let now = Date()
        let b1 = Budget(id: id, name: "Groceries", amount: 500, categoryId: UUID(), period: .monthly, startDate: now)
        let b2 = Budget(id: id, name: "Groceries", amount: 500, categoryId: b1.categoryId, period: .monthly, startDate: now)
        
        #expect(b1.hashValue == b2.hashValue)
    }

    @Test("Budget Codable round-trip")
    func testCodable() throws {
        let budget = Budget(name: "Groceries", amount: 500, period: .monthly, startDate: Date())
        
        let data = try JSONEncoder().encode(budget)
        let decoded = try JSONDecoder().decode(Budget.self, from: data)
        #expect(decoded == budget)
    }
}
