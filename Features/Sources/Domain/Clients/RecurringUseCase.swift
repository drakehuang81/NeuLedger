import Foundation
import Dependencies
import DependenciesMacros

/// Application-layer use case for recurring transaction templates.
///
/// Surface follows `docs/architecture.md` §5 Planning Context. Wraps
/// `RecurringTransactionClient` for CRUD and implements the `tick()`
/// scheduler entry point that materialises due templates into real
/// transactions via `LedgerUseCase.record` (architecture.md §3.1
/// Scenario A — fixed UseCase→UseCase whitelist).
@DependencyClient
public struct RecurringUseCase: Sendable {
    public var listActive: @Sendable () async throws -> [RecurringTransaction]

    public var create: @Sendable (_ template: RecurringTransaction) async throws -> Void
    public var update: @Sendable (_ template: RecurringTransaction) async throws -> Void
    public var delete: @Sendable (_ id: RecurringTransaction.ID) async throws -> Void

    /// Scheduler entry point. For every active template whose
    /// `nextDueDate` is on or before `now`, records a `Transaction`
    /// via `LedgerUseCase.record` and advances the template's
    /// `nextDueDate` by one period. Idempotency hinges on the
    /// `nextDueDate` advance happening in the same call as the
    /// `record` — partial failures (record OK, update template FAIL)
    /// would re-emit the same transaction on next tick.
    public var tick: @Sendable () async throws -> Void
}

extension RecurringUseCase: TestDependencyKey {
    public static let testValue = Self()
}

public extension DependencyValues {
    var recurringUseCase: RecurringUseCase {
        get { self[RecurringUseCase.self] }
        set { self[RecurringUseCase.self] = newValue }
    }
}
