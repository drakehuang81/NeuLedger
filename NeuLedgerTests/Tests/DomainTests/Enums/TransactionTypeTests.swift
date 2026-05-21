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

    @Test("TransactionType.displayName returns localized key string")
    func testDisplayName() {
        // String(localized:) in Domain resolves against Bundle.main at runtime.
        // In isolated test targets the bundle may not be present — verify non-empty
        // and distinct as a bundle-agnostic guard.
        #expect(!TransactionType.expense.displayName.isEmpty)
        #expect(!TransactionType.income.displayName.isEmpty)
        #expect(!TransactionType.transfer.displayName.isEmpty)
        let names = TransactionType.allCases.map(\.displayName)
        #expect(Set(names).count == 3)
        // All three map to different localization keys (common_expense/income/transfer).
        // When bundle is absent String(localized:) returns the key — still distinct.
    }

    @Test("TransactionType.systemImageName returns SF Symbol names")
    func testSystemImageName() {
        #expect(TransactionType.expense.systemImageName == "arrow.up.circle.fill")
        #expect(TransactionType.income.systemImageName == "arrow.down.circle.fill")
        #expect(TransactionType.transfer.systemImageName == "arrow.left.arrow.right.circle.fill")
    }
}
