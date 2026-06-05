import Foundation
import Dependencies
import Domain
import SwiftData

/// Receives inbound payloads from the watchOS companion app and commits
/// them into SwiftData via `SwiftDataStore`. Uses
/// `ProcessedDraftIdsStore` to discard retried sends of the same draft.
///
/// Wire-format (must stay in sync with the Watch sender, added in Phase 2):
///   ```
///   ["op": "addTx", "payload": <Data — JSON-encoded TransactionDraft>]
///   ```
public final class WatchSessionDelegate: @unchecked Sendable {

    private let transport: WatchSessionTransport
    private let dedupStore: ProcessedDraftIdsStore

    public init(transport: WatchSessionTransport, dedupStore: ProcessedDraftIdsStore = ProcessedDraftIdsStore()) {
        self.transport = transport
        self.dedupStore = dedupStore
    }

    /// Begin listening for inbound payloads. Calling more than once
    /// replaces the previous handler.
    public func start() {
        transport.onReceiveUserInfo { [weak self] payload in
            // Parse and validate synchronously on the calling context.
            // Only a fully-typed Sendable `Transaction` enters the async Task.
            guard let transaction = self?.parse(payload) else { return }
            Task {
                let store = TransactionStore()
                try? await store.add(transaction)
            }
        }
    }

    /// Parse, validate, and deduplicate the raw payload.
    /// Returns a ready-to-commit `Transaction` or `nil` if the payload
    /// should be dropped.
    private func parse(_ payload: [String: Any]) -> Transaction? {
        guard let op = payload["op"] as? String, op == "addTx" else { return nil }
        guard let data = payload["payload"] as? Data else { return nil }
        guard let draft = try? JSONDecoder().decode(TransactionDraft.self, from: data) else { return nil }
        guard draft.isValid else { return nil }
        guard !dedupStore.contains(draft.id) else { return nil }
        dedupStore.mark(draft.id)

        return Transaction(
            id: draft.id,
            amount: draft.amount,
            date: draft.date,
            categoryId: draft.categoryId,
            accountId: draft.accountId,
            type: .expense
        )
    }
}
