import Foundation
import Testing
import Dependencies
import ComposableArchitecture
import Domain
@testable import Core

@Suite("WatchSessionDelegate Tests")
struct WatchSessionDelegateTests {

    /// Fake transport that only exercises the `onReceiveUserInfo` path.
    final class FakeTransport: WatchSessionTransport, @unchecked Sendable {
        var isActivated = false
        var isPaired = false
        var isWatchAppInstalled = false
        private var handler: (@Sendable ([String: Any]) -> Void)?

        func activate() { isActivated = true }
        func updateApplicationContext(_ context: [String: Any]) throws {}
        func onReceiveUserInfo(_ handler: @escaping @Sendable ([String: Any]) -> Void) {
            self.handler = handler
        }
        func deliver(_ payload: [String: Any]) { handler?(payload) }
    }

    private func makeDedupStore() -> ProcessedDraftIdsStore {
        let suite = "WatchSessionDelegateTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return ProcessedDraftIdsStore(defaults: defaults, capacity: 10)
    }

    private func encodeDraft(_ draft: TransactionDraft) throws -> [String: Any] {
        let data = try JSONEncoder().encode(draft)
        return [
            "op": "addTx",
            "payload": data
        ]
    }

    @Test("Valid draft is forwarded to transactionClient.add as an expense")
    func validDraftIsForwardedToTransactionClient() async throws {
        let transport = FakeTransport()
        let dedup = makeDedupStore()
        let draft = TransactionDraft(
            categoryId: UUID(),
            accountId: UUID().uuidString,
            amount: 480
        )

        let added = LockIsolated<[Transaction]>([])

        await withDependencies {
            $0.transactionClient.add = { @Sendable transaction in
                added.withValue { $0.append(transaction) }
            }
        } operation: {
            let delegate = WatchSessionDelegate(transport: transport, dedupStore: dedup)
            delegate.start()
            transport.deliver(try! encodeDraft(draft))
            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        let committed = added.value
        #expect(committed.count == 1)
        #expect(committed.first?.id == draft.id)
        #expect(committed.first?.amount == 480)
        #expect(committed.first?.accountId == draft.accountId)
        #expect(committed.first?.categoryId == draft.categoryId)
        #expect(committed.first?.type == .expense)
    }

    @Test("Duplicate draft delivered twice only commits once")
    func duplicateDraftIsIgnored() async throws {
        let transport = FakeTransport()
        let dedup = makeDedupStore()
        let draft = TransactionDraft(
            categoryId: UUID(),
            accountId: UUID().uuidString,
            amount: 100
        )

        let callCount = LockIsolated(0)

        await withDependencies {
            $0.transactionClient.add = { @Sendable _ in
                callCount.withValue { $0 += 1 }
            }
        } operation: {
            let delegate = WatchSessionDelegate(transport: transport, dedupStore: dedup)
            delegate.start()
            transport.deliver(try! encodeDraft(draft))
            try? await Task.sleep(nanoseconds: 100_000_000)
            transport.deliver(try! encodeDraft(draft))
            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        #expect(callCount.value == 1)
    }

    @Test("Malformed payload (non-Data) is silently ignored")
    func invalidPayloadIsIgnored() async throws {
        let transport = FakeTransport()
        let dedup = makeDedupStore()
        let callCount = LockIsolated(0)

        await withDependencies {
            $0.transactionClient.add = { @Sendable _ in
                callCount.withValue { $0 += 1 }
            }
        } operation: {
            let delegate = WatchSessionDelegate(transport: transport, dedupStore: dedup)
            delegate.start()
            transport.deliver(["op": "addTx", "payload": "not-data"])
            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        #expect(callCount.value == 0)
    }
}
