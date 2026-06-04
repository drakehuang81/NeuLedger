import Foundation
import Dependencies
import DependenciesMacros
import Domain

/// Minimal protocol the Watch ledger client needs from
/// `WatchSessionGateway`. Lets the client be unit-tested with a fake
/// without pulling the full gateway into tests.
public protocol WatchDraftSender: Sendable {
    func send(draft: TransactionDraft)
}

extension WatchSessionGateway: WatchDraftSender {}

/// Watch-side ledger client. The Apple Watch is an independent
/// presentation context with only three needs:
///
/// - read the cached active accounts pushed from the iPhone,
/// - read the cached categories for a given transaction type,
/// - relay a newly recorded transaction back to the iPhone via
///   WatchConnectivity (no local SwiftData write).
///
/// It deliberately stays narrow rather than depending on the full
/// iPhone-side `LedgerClient`.
@DependencyClient
public struct WatchLedgerClient: Sendable {
    /// Active (unarchived) accounts from the iPhone snapshot cache.
    public var activeAccounts: @Sendable () async throws -> [Account]

    /// Categories of the given type from the iPhone snapshot cache.
    public var categories: @Sendable (_ type: TransactionType) async throws -> [Domain.Category]

    /// Relays a recorded transaction to the iPhone via the session
    /// gateway. This is a forward, not a local write.
    public var record: @Sendable (_ transaction: Transaction) async throws -> Void
}

extension WatchLedgerClient: TestDependencyKey {
    public static let testValue = Self()
}

public extension DependencyValues {
    var watchLedgerClient: WatchLedgerClient {
        get { self[WatchLedgerClient.self] }
        set { self[WatchLedgerClient.self] = newValue }
    }
}

extension WatchLedgerClient {

    /// Watch-side live value. Read methods consult `WatchCacheStore`
    /// (data pushed by the iPhone); `record` forwards a draft through the
    /// session gateway. Watch has no entry point for editing accounts or
    /// categories, so no mutation paths exist beyond `record`.
    public static func watchLive(
        cache: WatchCacheStore,
        gateway: WatchDraftSender
    ) -> WatchLedgerClient {
        WatchLedgerClient(
            activeAccounts: {
                (cache.load()?.accounts ?? []).filter { $0.isArchived == false }
            },
            categories: { type in
                (cache.load()?.categories ?? []).filter { $0.type == type }
            },
            record: { transaction in
                guard let categoryId = transaction.categoryId else { return }
                let draft = TransactionDraft(
                    id: transaction.id,
                    categoryId: categoryId,
                    accountId: transaction.accountId,
                    amount: transaction.amount,
                    date: transaction.date
                )
                gateway.send(draft: draft)
            }
        )
    }
}
