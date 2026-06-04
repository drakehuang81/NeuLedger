import Foundation
import Testing
import SwiftData
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

    /// Fresh in-memory SwiftData container per test so the delegate's direct
    /// `SwiftDataStore<Transaction, SDTransaction>` writes can be asserted by
    /// reading rows back out. Mirrors the pattern in `LedgerClientLiveTests`.
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            SDTransaction.self,
            SDAccount.self,
            SDCategory.self,
            SDBudget.self,
            SDTag.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private func storedTransactions(in container: ModelContainer) async throws -> [Transaction] {
        try await withDependencies {
            $0.modelContainer = container
        } operation: {
            try await SwiftDataStore<Transaction, SDTransaction>().fetchAll()
        }
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

    @Test("Valid draft is forwarded to the SwiftData store as an expense")
    func validDraftIsForwardedToStore() async throws {
        let transport = FakeTransport()
        let dedup = makeDedupStore()
        let container = try makeContainer()
        let draft = TransactionDraft(
            categoryId: UUID(),
            accountId: UUID().uuidString,
            amount: 480
        )

        await withDependencies {
            $0.modelContainer = container
        } operation: {
            let delegate = WatchSessionDelegate(transport: transport, dedupStore: dedup)
            delegate.start()
            transport.deliver(try! encodeDraft(draft))
            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        let committed = try await storedTransactions(in: container)
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
        let container = try makeContainer()
        let draft = TransactionDraft(
            categoryId: UUID(),
            accountId: UUID().uuidString,
            amount: 100
        )

        await withDependencies {
            $0.modelContainer = container
        } operation: {
            let delegate = WatchSessionDelegate(transport: transport, dedupStore: dedup)
            delegate.start()
            transport.deliver(try! encodeDraft(draft))
            try? await Task.sleep(nanoseconds: 100_000_000)
            transport.deliver(try! encodeDraft(draft))
            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        let committed = try await storedTransactions(in: container)
        #expect(committed.count == 1)
    }

    @Test("Malformed payload (non-Data) is silently ignored")
    func invalidPayloadIsIgnored() async throws {
        let transport = FakeTransport()
        let dedup = makeDedupStore()
        let container = try makeContainer()

        await withDependencies {
            $0.modelContainer = container
        } operation: {
            let delegate = WatchSessionDelegate(transport: transport, dedupStore: dedup)
            delegate.start()
            transport.deliver(["op": "addTx", "payload": "not-data"])
            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        let committed = try await storedTransactions(in: container)
        #expect(committed.isEmpty)
    }
}
