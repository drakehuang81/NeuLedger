import Foundation
import Testing
@testable import Domain

@Suite("AccountType Tests")
struct AccountTypeTests {
    @Test("AccountType has correct cases")
    func testCases() {
        #expect(AccountType.allCases.count == 4)
        #expect(AccountType.allCases.contains(.cash))
        #expect(AccountType.allCases.contains(.bank))
        #expect(AccountType.allCases.contains(.creditCard))
        #expect(AccountType.allCases.contains(.eWallet))
    }

    @Test("AccountType Codable round-trip")
    func testCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for type in AccountType.allCases {
            let data = try encoder.encode(type)
            let decoded = try decoder.decode(AccountType.self, from: data)
            #expect(decoded == type)
        }
    }
}
