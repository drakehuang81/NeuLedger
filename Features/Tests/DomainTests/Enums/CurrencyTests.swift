import Foundation
import Testing
@testable import Domain

@Suite("Currency Tests")
struct CurrencyTests {
    @Test("Currency properties")
    func testProperties() {
        let twd = Currency.TWD
        #expect(twd.code == "TWD")
        #expect(twd.symbol == "NT$")
        #expect(twd.decimalPlaces == 0)
    }

    @Test("Currency Codable round-trip")
    func testCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for type in Currency.allCases {
            let data = try encoder.encode(type)
            let decoded = try decoder.decode(Currency.self, from: data)
            #expect(decoded == type)
        }
    }
}
