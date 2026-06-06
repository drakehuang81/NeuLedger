import Foundation
import SwiftData
import Domain

/// Resolves the effective default account for Watch-bound snapshots.
///
/// Delegates the resolution rule to `Account.resolveDefaultId(stored:in:)`,
/// which is the single source of truth shared by `WatchSyncObserver`,
/// `WatchMidnightTimer`, `PlatformClient.pushWatchContext`, and
/// `WatchSettingsFeature`. Returns `nil` when there is genuinely no active
/// account — the Watch has nothing useful to show then.
///
/// Infrastructure-layer collaborator in the Watch sync pipeline: reads
/// SwiftData directly via `SwiftDataStore` (same-layer, legal — see
/// docs/architecture.md §10).
public enum WatchDefaultAccountResolver {

    public static func resolve(stored: Account.ID?) async throws -> Account.ID? {
        let activeAccounts = try await AccountStore()
            .fetchAll(sortBy: [SortDescriptor(\.sortOrder)])
            .filter { !$0.isArchived }
        return Account.resolveDefaultId(stored: stored, in: activeAccounts)
    }
}
