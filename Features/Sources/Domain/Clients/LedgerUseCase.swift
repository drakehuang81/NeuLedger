import Foundation
import Dependencies
import DependenciesMacros

/// Application-layer use case for transaction mutations.
///
/// Currently exposes only the mutation surface — `record`, `update`,
/// `delete`. The read surface (`fetch`, `listRecent`, `listAll(filter:)`,
/// `search`) returning `EnrichedTransaction` defined in
/// `docs/architecture.md` §5 Ledger Context lands in Phase 5.
///
/// Per architecture.md §3.1 Scenario B (post-condition invariant),
/// `record` and `update` invoke `BudgetUseCase.evaluateAfterTransaction`
/// after the write succeeds. Callers must NEVER call
/// `TransactionClient.add/update` directly — every transaction mutation
/// goes through `LedgerUseCase` so the budget-warning side-effect cannot
/// be skipped.
@DependencyClient
public struct LedgerUseCase: Sendable {
    /// Persist a new transaction and run the budget-warning invariant.
    public var record: @Sendable (_ transaction: Transaction) async throws -> Void

    /// Update an existing transaction and run the budget-warning invariant.
    public var update: @Sendable (_ transaction: Transaction) async throws -> Void

    /// Delete a transaction by id. No budget-warning invariant — the warning
    /// is intentionally a 'crossing detector' for income/expense growth, not
    /// for deletions, matching the pre-LedgerUseCase behavior.
    public var delete: @Sendable (_ id: Transaction.ID) async throws -> Void
}

extension LedgerUseCase: TestDependencyKey {
    public static let testValue = Self()
}

public extension DependencyValues {
    var ledger: LedgerUseCase {
        get { self[LedgerUseCase.self] }
        set { self[LedgerUseCase.self] = newValue }
    }
}
