import Foundation
import Dependencies
import DependenciesMacros

/// Application-layer use case for budget concerns.
///
/// Currently exposes only the post-transaction evaluation hook — the
/// full CRUD surface (`listActive`, `create`, `update`, `delete`,
/// `currentStatus(of:)`) defined in `docs/architecture.md` §5 Planning
/// Context lands in Phase 5.
@DependencyClient
public struct BudgetUseCase: Sendable {
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
