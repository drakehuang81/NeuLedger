import Foundation
import Dependencies
import DependenciesMacros

/// Application-layer use case for budget concerns.
///
/// Surface follows `docs/architecture.md` §5 Planning Context. Wraps
/// `BudgetClient` (Repository) for CRUD + composes
/// `BudgetWarningPolicy` + `TransactionClient` for read-side queries
/// (`currentStatus`) and the post-transaction evaluation side effect
/// (`evaluateAfterTransaction`).
@DependencyClient
public struct BudgetUseCase: Sendable {
    /// Active budgets — those flagged `isActive` and within their
    /// configured period.
    public var listActive: @Sendable () async throws -> [Budget]

    public var create: @Sendable (_ budget: Budget) async throws -> Void
    public var update: @Sendable (_ budget: Budget) async throws -> Void
    public var delete: @Sendable (_ id: Budget.ID) async throws -> Void

    /// Computes the current-period spending status for a single
    /// budget. Period boundaries follow the calendar (`weekOfYear`,
    /// `month`, `year`). Throws if the underlying transaction fetch
    /// fails.
    public var currentStatus: @Sendable (_ budget: Budget) async throws -> BudgetStatus = { budget in
        BudgetStatus(budget: budget, periodStart: .distantPast, periodEnd: .distantPast, spent: 0)
    }

    /// Run the budget-warning evaluation after a transaction is recorded
    /// or modified. Reads active budgets, computes spent-in-period via
    /// `BudgetWarningPolicy`, and fires a notification if a threshold
    /// is crossed for the first time in the current period.
    ///
    /// Pure side-effect; no return value. Errors are swallowed —
    /// notifications are best-effort and the caller must not fail a
    /// successful `record(_:)` just because a warning couldn't go out.
    public var evaluateAfterTransaction: @Sendable (_ transaction: Transaction) async -> Void
}

extension BudgetUseCase: TestDependencyKey {
    public static let testValue = Self()
}

public extension DependencyValues {
    var budgetUseCase: BudgetUseCase {
        get { self[BudgetUseCase.self] }
        set { self[BudgetUseCase.self] = newValue }
    }
}
