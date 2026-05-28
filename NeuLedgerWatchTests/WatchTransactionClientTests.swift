import Foundation
import Testing
import Dependencies
import Domain
import ConcurrencyExtras
@testable import WatchFeatures

@Suite("WatchTransactionClient Tests")
struct WatchTransactionClientTests {

    final class FakeGateway: WatchDraftSender, @unchecked Sendable {
        let sent = LockIsolated<[TransactionDraft]>([])
        func send(draft: TransactionDraft) {
            sent.withValue { $0.append(draft) }
        }
    }

    @Test("add converts Transaction to TransactionDraft and forwards to the gateway")
    func addForwardsToGateway() async throws {
        let gateway = FakeGateway()
        let client = TransactionClient.watchLive(gateway: gateway)

        let tx = Transaction(
            id: UUID(),
            amount: 250,
            date: Date(timeIntervalSince1970: 1_700_000_000),
            categoryId: UUID(),
            accountId: UUID(),
            type: .expense
        )

        try await client.add(tx)

        let sent = gateway.sent.value
        #expect(sent.count == 1)
        #expect(sent.first?.id == tx.id)
        #expect(sent.first?.amount == 250)
        #expect(sent.first?.categoryId == tx.categoryId)
        #expect(sent.first?.accountId == tx.accountId)
    }

    @Test("add drops a transaction whose categoryId is nil")
    func addDropsTransactionWithNilCategory() async throws {
        let gateway = FakeGateway()
        let client = TransactionClient.watchLive(gateway: gateway)

        let tx = Transaction(
            amount: 100,
            date: Date(),
            categoryId: nil,
            accountId: UUID(),
            type: .expense
        )

        // Should not throw, just no-op.
        try await client.add(tx)
        #expect(gateway.sent.value.isEmpty)
    }
}
