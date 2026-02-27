import Foundation
import Testing
@testable import Domain

@Suite("Account Tests")
struct AccountTests {
    @Test("Account Initialization and Equatable")
    func testInitializationAndEquatable() {
        let accountId = UUID()
        let now = Date()
        let acc1 = Account(id: accountId, name: "Cash", type: .cash, icon: "dollarsign", color: "#FFFFFF", createdAt: now)
        let acc2 = Account(id: accountId, name: "Cash", type: .cash, icon: "dollarsign", color: "#FFFFFF", createdAt: now)
        let acc3 = Account(name: "Bank", type: .bank, icon: "building", color: "#000000")
        
        #expect(acc1 == acc2)
        #expect(acc1 != acc3)
        #expect(acc1.sortOrder == 0)
        #expect(acc1.isArchived == false)
    }

    @Test("Account Hashable")
    func testHashable() {
        let id = UUID()
        let now = Date()
        let acc1 = Account(id: id, name: "Cash", type: .cash, icon: "dollarsign", color: "#FFFFFF", createdAt: now)
        let acc2 = Account(id: id, name: "Cash", type: .cash, icon: "dollarsign", color: "#FFFFFF", createdAt: now)
        let acc3 = Account(id: UUID(), name: "Cash", type: .cash, icon: "dollarsign", color: "#FFFFFF", createdAt: now)
        
        #expect(acc1.hashValue == acc2.hashValue)
        #expect(acc1.hashValue != acc3.hashValue)
    }

    @Test("Account Codable round-trip")
    func testCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let acc = Account(name: "Cash", type: .cash, icon: "dollarsign", color: "#FFFFFF")
        
        let data = try encoder.encode(acc)
        let decoded = try decoder.decode(Account.self, from: data)
        #expect(decoded == acc)
    }
}
