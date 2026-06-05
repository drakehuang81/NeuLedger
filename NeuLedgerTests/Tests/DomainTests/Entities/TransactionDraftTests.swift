import Foundation
import Testing
@testable import Domain

@Suite("TransactionDraft Tests")
struct TransactionDraftTests {

    @Test("Codable round-trip preserves all fields")
    func encodesAndDecodes() throws {
        let original = TransactionDraft(
            id: UUID(),
            categoryId: UUID(),
            accountId: UUID().uuidString,
            amount: 480,
            date: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TransactionDraft.self, from: data)

        #expect(decoded == original)
    }

    @Test("isValid is true only when amount > 0")
    func isValidRequiresPositiveAmount() {
        let zero = TransactionDraft(
            id: UUID(),
            categoryId: UUID(),
            accountId: UUID().uuidString,
            amount: 0,
            date: Date()
        )
        let positive = TransactionDraft(
            id: UUID(),
            categoryId: UUID(),
            accountId: UUID().uuidString,
            amount: 1,
            date: Date()
        )
        let negative = TransactionDraft(
            id: UUID(),
            categoryId: UUID(),
            accountId: UUID().uuidString,
            amount: -1,
            date: Date()
        )

        #expect(zero.isValid == false)
        #expect(positive.isValid == true)
        #expect(negative.isValid == false)
    }
}
