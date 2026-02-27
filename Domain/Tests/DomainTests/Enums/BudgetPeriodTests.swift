import Foundation
import Testing
@testable import Domain

@Suite("BudgetPeriod Tests")
struct BudgetPeriodTests {
    @Test("BudgetPeriod has correct cases")
    func testCases() {
        #expect(BudgetPeriod.allCases.count == 3)
        #expect(BudgetPeriod.allCases.contains(.weekly))
        #expect(BudgetPeriod.allCases.contains(.monthly))
        #expect(BudgetPeriod.allCases.contains(.yearly))
    }

    @Test("BudgetPeriod Codable round-trip")
    func testCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for type in BudgetPeriod.allCases {
            let data = try encoder.encode(type)
            let decoded = try decoder.decode(BudgetPeriod.self, from: data)
            #expect(decoded == type)
        }
    }
}
