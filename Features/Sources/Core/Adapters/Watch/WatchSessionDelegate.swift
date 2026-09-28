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

    // In-memory guard against the write-in-progress race: `dedupStore.mark`
    // only happens after `add` succeeds (audit A8), so two payloads for the
    // same draft delivered back-to-back both pass `dedupStore.contains`
    // before the first write finishes — without this, both would commit,
    // turning "silently lost" into "silently duplicated". Deliberately
    // in-memory (not persisted like `ProcessedDraftIdsStore`): a crash
    // clears it, so a draft that was in-flight but never finished writing
    // is neither processed nor in-flight afterwards, and a resend can still
    // recover it. `NSLock`-guarded, mirroring `ProcessedDraftIdsStore`.
    private let inFlightLock = NSLock()
    private var inFlightDraftIds: Set<UUID> = []

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
                    // 刻意不回報這個錯誤——不是因為缺基礎建設：
                    // `platformClient.recordError` 存在且已接 Crashlytics
                    // （PlatformClient+Live.swift、Core 已連結 firebaseCrashlytics）。
                    // 不接的原因是它目前零消費者，這裡會是第一個，等於替整個
                    // App 決定「什麼該回報」；而且 `PlatformClient` 本身的分層
                    // 問題尚未解決（audit #29），現在讓這個 adapter 依賴它可能
                    // 固化 PR C 想拆開的東西。已列為 follow-up。
                    // 這裡的重點是不要 mark，讓重送能救回這筆帳。
                }
                // 無論成功或失敗都要解除 in-flight：成功後 `dedupStore` 接手擋重送，
                // 失敗後讓下一次重送能重新通過 `parse` 再試一次。
                self.clearInFlight(transaction.id)
            }
        }
    }

    /// Parse, validate, and deduplicate the raw payload.
    /// Returns a ready-to-commit `Transaction` or `nil` if the payload
    /// should be dropped. Does **not** mark the draft as processed in
    /// `dedupStore` — that only happens after `add` succeeds (see
    /// `start()`). It *does* claim the id in the in-flight set so a
    /// second delivery arriving before the first write finishes is
    /// rejected too (see `inFlightDraftIds` above).
    private func parse(_ payload: [String: Any]) -> Transaction? {
        guard let op = payload["op"] as? String, op == "addTx" else { return nil }
        guard let data = payload["payload"] as? Data else { return nil }
        guard let draft = try? JSONDecoder().decode(TransactionDraft.self, from: data) else { return nil }
        guard draft.isValid else { return nil }
        guard !dedupStore.contains(draft.id) else { return nil }
        // Claims the id in the in-flight set; rejects if another delivery
        // of the same draft already claimed it and hasn't finished writing.
        guard claimInFlight(draft.id) else { return nil }

        return Transaction(
            id: draft.id,
            amount: draft.amount,
            date: draft.date,
            categoryId: draft.categoryId,
            accountId: draft.accountId,
            type: .expense
        )
    }

    /// Atomically checks whether `id` is already in-flight and, if not,
    /// claims it. Returns `true` if this call claimed the id (it wasn't
    /// already in-flight); `false` if another delivery already claimed it
    /// and this payload should be dropped.
    private func claimInFlight(_ id: UUID) -> Bool {
        inFlightLock.lock(); defer { inFlightLock.unlock() }
        if inFlightDraftIds.contains(id) { return false }
        inFlightDraftIds.insert(id)
        return true
    }

    /// Releases `id` from the in-flight set once its `add` attempt (success
    /// or failure) has finished.
    private func clearInFlight(_ id: UUID) {
        inFlightLock.lock(); defer { inFlightLock.unlock() }
        inFlightDraftIds.remove(id)
    }
}
