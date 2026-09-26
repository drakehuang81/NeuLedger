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
    private let add: @Sendable (Transaction) async throws -> Void

    // `add`'s default can't be spelled as a default *argument value* — the
    // real implementation reaches for `TransactionStore`, an `internal`
    // typealias, and a `public` init may not reference a less-visible type
    // in its default expression. So the parameter defaults to `nil` (a
    // fully public-safe default) and the real closure is assembled in the
    // init's body instead, where visibility rules don't apply.
    public init(
        transport: WatchSessionTransport,
        dedupStore: ProcessedDraftIdsStore = ProcessedDraftIdsStore(),
        add: (@Sendable (Transaction) async throws -> Void)? = nil
    ) {
        self.transport = transport
        self.dedupStore = dedupStore
        self.add = add ?? { transaction in
            try await TransactionStore().add(transaction)
        }
    }

    /// Begin listening for inbound payloads. Calling more than once
    /// replaces the previous handler.
    public func start() {
        transport.onReceiveUserInfo { [weak self] payload in
            // Parse and validate synchronously on the calling context.
            // Only a fully-typed Sendable `Transaction` enters the async Task.
            guard let self, let transaction = self.parse(payload) else { return }
            Task {
                do {
                    try await self.add(transaction)
                    // 標記必須在寫入成功之後：失敗時保留 id，讓 WatchConnectivity
                    // 重送同一個 transferUserInfo 有機會補上（audit A8）。
                    self.dedupStore.mark(transaction.id)
                } catch {
                    // 刻意不 log：全專案目前沒有 logging 基礎建設，引入它是另一張單。
                    // 這裡的重點是不要 mark，讓重送能救回這筆帳。
                }
            }
        }
    }

    /// Parse, validate, and deduplicate the raw payload.
    /// Returns a ready-to-commit `Transaction` or `nil` if the payload
    /// should be dropped. Does **not** mark the draft as processed —
    /// that only happens after `add` succeeds (see `start()`).
    private func parse(_ payload: [String: Any]) -> Transaction? {
        guard let op = payload["op"] as? String, op == "addTx" else { return nil }
        guard let data = payload["payload"] as? Data else { return nil }
        guard let draft = try? JSONDecoder().decode(TransactionDraft.self, from: data) else { return nil }
        guard draft.isValid else { return nil }
        guard !dedupStore.contains(draft.id) else { return nil }

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
