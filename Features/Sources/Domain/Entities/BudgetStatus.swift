import Foundation

/// The current-period spending state of a `Budget`.
///
/// Returned by `BudgetUseCase.currentStatus(of:)`. Pure data — no
/// formatting, no localization, no presentation concerns. Consumers
/// (Analytics views, Settings detail screen) derive their own display
/// labels.
///
/// Period boundaries are inclusive on the start and exclusive on the
/// end (DateInterval semantics), matching the convention used by
/// `BudgetWarningPolicy` and the rest of the codebase.
public struct BudgetStatus: Equatable, Sendable {
    public let budget: Budget
    public let periodStart: Date
    public let periodEnd: Date
    public let spent: Decimal

    public init(budget: Budget, periodStart: Date, periodEnd: Date, spent: Decimal) {
        self.budget = budget
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.spent = spent
    }

    /// Remaining budget for the period. Clamped at zero — going past
    /// 100 % does not produce a negative remaining; use `isOverBudget`
    /// to detect overshoot.
    public var remaining: Decimal {
        max(0, budget.amount - spent)
    }

    /// Used-budget proportion in the range `[0, +∞)` as a `Double`.
    /// `1.0` means exactly hitting the budget; `> 1.0` means exceeded.
    public var progress: Double {
        guard budget.amount > 0 else { return 0 }
        return NSDecimalNumber(decimal: spent / budget.amount).doubleValue
    }

    /// `progress` expressed as an integer percent (rounded down), the
    /// representation used by the warning notification subsystem so
    /// `BudgetWarningPolicy` and consumers stay consistent.
    public var usedPercent: Int {
        let pct = progress * 100
        return Int(pct.rounded(.down))
    }

    public var isOverBudget: Bool {
        spent > budget.amount
    }
}
