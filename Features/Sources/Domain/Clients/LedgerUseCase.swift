import Foundation
import Dependencies
import DependenciesMacros

/// Application-layer use case for transaction CRUD + enriched reads.
///
/// Surface follows `docs/architecture.md` §5 Ledger Context. Mutation
/// endpoints (`record`, `update`, `delete`) preserve the architecture.md
/// §3.1 Scenario B invariant by routing `BudgetUseCase.evaluateAfter
/// Transaction` after each write — callers must NEVER call
/// `TransactionClient.add/update` directly.
///
/// Read endpoints (`fetch`, `listRecent`, `listAll(filter:)`, `search`)
/// return `EnrichedTransaction` so the UI does not have to re-join
/// against categories / accounts on every render.
@DependencyClient
public struct LedgerUseCase: Sendable {
    // MARK: - Mutations

    public var record: @Sendable (_ transaction: Transaction) async throws -> Void
    public var update: @Sendable (_ transaction: Transaction) async throws -> Void
    public var delete: @Sendable (_ id: Transaction.ID) async throws -> Void

    // MARK: - Reads

    public var fetch: @Sendable (_ id: Transaction.ID) async throws -> EnrichedTransaction?
    public var listRecent: @Sendable (_ limit: Int) async throws -> [EnrichedTransaction] = { _ in [] }
    public var listAll: @Sendable (_ filter: TransactionFilter) async throws -> [EnrichedTransaction] = { _ in [] }
    public var search: @Sendable (_ query: String) async throws -> [EnrichedTransaction] = { _ in [] }
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
