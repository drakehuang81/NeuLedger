import Foundation
import Dependencies
import DependenciesMacros

/// A client interface for the Planning context — budget definitions, their
/// current-period spending status, the post-transaction warning evaluation
/// side effect, and the budget-warning user preferences.
///
/// `PlanningClient` consolidates what previously lived across `BudgetClient`
/// (Repository CRUD), `BudgetUseCase` (status + evaluation), and the
/// budget-warning preferences formerly owned by `AppEnvironmentUseCase`. The
/// Features layer drives all budget concerns through this single client.
@DependencyClient
public struct PlanningClient: Sendable {
    /// Fetches all budget records, including past or inactive ones.
    public var listAll: @Sendable () async throws -> [Budget]

    /// Active budgets — those flagged `isActive`.
    public var listActive: @Sendable () async throws -> [Budget]

    /// Persists a newly created budget.
    public var create: @Sendable (_ budget: Budget) async throws -> Void

    /// Updates an existing budget. Its `id` must match an existing record.
    public var update: @Sendable (_ budget: Budget) async throws -> Void

    /// Removes a budget from storage.
    public var delete: @Sendable (_ id: Budget.ID) async throws -> Void

    /// Computes the current-period spending status for a single budget.
    /// Period boundaries follow the calendar (`weekOfYear`, `month`, `year`).
    /// Throws if the underlying transaction fetch fails.
    public var currentStatus: @Sendable (_ budget: Budget) async throws -> BudgetStatus = { budget in
        BudgetStatus(budget: budget, periodStart: .distantPast, periodEnd: .distantPast, spent: 0)
    }

    /// INVARIANT 入口：由 Ledger 的 record/update 呼叫（§3.1）。
    ///
    /// Run the budget-warning evaluation after a transaction is recorded or
    /// modified. Reads active budgets, computes spent-in-period via
    /// `BudgetWarningPolicy`, and fires a notification if a threshold is
    /// crossed for the first time in the current period.
    ///
    /// Pure side-effect; no return value. Errors are swallowed —
    /// notifications are best-effort and the caller must not fail a
    /// successful `record(_:)` just because a warning couldn't go out.
    public var evaluateAfterTransaction: @Sendable (_ transaction: Transaction) async -> Void

    /// Whether budget overspend warning notifications are enabled.
    public var warningEnabled: @Sendable () -> Bool = { false }

    /// Sets whether budget overspend warning notifications are enabled.
    public var setWarningEnabled: @Sendable (_ enabled: Bool) -> Void

    /// The warning threshold as an integer percentage (e.g. `80`).
    public var warningThreshold: @Sendable () -> Int = { 80 }

    /// Sets the warning threshold as an integer percentage.
    public var setWarningThreshold: @Sendable (_ percent: Int) -> Void
}

extension PlanningClient: TestDependencyKey {
    public static let testValue = Self()
}

public extension DependencyValues {
    var planningClient: PlanningClient {
        get { self[PlanningClient.self] }
        set { self[PlanningClient.self] = newValue }
    }
}
