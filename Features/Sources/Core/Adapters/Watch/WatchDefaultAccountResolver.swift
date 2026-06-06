import Foundation
import SwiftData
import Domain

/// Resolves the effective default account for Watch-bound snapshots.
///
/// Single source of truth for the rule shared by `WatchSyncObserver`,
/// `WatchMidnightTimer`, and `PlatformClient.pushWatchContext`: honor the
/// stored Settings override only while it still points at a live (existing,
/// non-archived) account; otherwise fall back to the sortOrder-first active
/// account. Returns `nil` when there is genuinely no active account — the
/// Watch has nothing useful to show then.
///
/// Infrastructure-layer collaborator in the Watch sync pipeline: reads
/// SwiftData directly via `SwiftDataStore` (same-layer, legal — see
/// docs/architecture.md §10).
public enum WatchDefaultAccountResolver {

    public static func resolve(stored: Account.ID?) async throws -> Account.ID? {
        let activeAccounts = try await AccountStore()
            .fetchAll(sortBy: [SortDescriptor(\.sortOrder)])
            .filter { !$0.isArchived }
        if let stored, activeAccounts.contains(where: { $0.id == stored }) {
            return stored
        }
        return activeAccounts.first?.id
    }
}
