import Foundation
import Testing
@testable import Domain

@Suite("TransactionType Tests")
struct TransactionTypeTests {
    @Test("TransactionType has correct cases")
    func testCases() {
        #expect(TransactionType.allCases.count == 3)
        #expect(TransactionType.allCases.contains(.income))
        #expect(TransactionType.allCases.contains(.expense))
        #expect(TransactionType.allCases.contains(.transfer))
    }

    @Test("TransactionType Codable round-trip")
    func testCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for type in TransactionType.allCases {
            let data = try encoder.encode(type)
            let decoded = try decoder.decode(TransactionType.self, from: data)
            #expect(decoded == type)
        }
    }
}
