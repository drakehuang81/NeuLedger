import Foundation
import Testing
@testable import Domain

@Suite
struct TransactionDraftTests {

    @Test
    func encodesAndDecodes() throws {
        let original = TransactionDraft(
            id: UUID(),
            categoryId: UUID(),
            accountId: UUID(),
            amount: 480,
            date: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TransactionDraft.self, from: data)

        #expect(decoded == original)
    }

    @Test
    func isValidRequiresPositiveAmount() {
        let zero = TransactionDraft(
            id: UUID(),
            categoryId: UUID(),
            accountId: UUID(),
            amount: 0,
            date: Date()
        )
        let positive = TransactionDraft(
            id: UUID(),
            categoryId: UUID(),
            accountId: UUID(),
            amount: 1,
            date: Date()
        )
        let negative = TransactionDraft(
            id: UUID(),
            categoryId: UUID(),
            accountId: UUID(),
            amount: -1,
            date: Date()
        )

        #expect(zero.isValid == false)
        #expect(positive.isValid == true)
        #expect(negative.isValid == false)
    }
}
