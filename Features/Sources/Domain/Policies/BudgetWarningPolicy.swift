import Foundation

/// Pure-function policy that decides whether to fire a budget warning,
/// and at what threshold percentage.
///
/// Lives in the Domain layer per `docs/architecture.md` §10 — policies are
/// pure Swift, no IO, no async. Repositories and UseCases call this and
/// drive the resulting `Outcome` to notifications / persisted state.
public enum BudgetWarningPolicy {
    /// The result of evaluating a budget against its in-period transactions.
    public struct Outcome: Equatable, Sendable {
        /// Whether the caller should fire a new warning notification now.
        /// True when `usedPercent >= threshold` AND the budget has not yet
        /// been warned at this threshold level for the current period.
        public let shouldWarn: Bool

        /// The percentage of the budget that has been spent (rounded down).
        /// Always in `0...Int.max`. Independent of `shouldWarn` so the
        /// caller can persist it for next-period comparison.
        public let usedPercent: Int

        public init(shouldWarn: Bool, usedPercent: Int) {
            self.shouldWarn = shouldWarn
            self.usedPercent = usedPercent
        }
    }

    /// Evaluate whether to fire a budget warning.
    ///
    /// - Parameters:
    ///   - budget: The budget being evaluated. `amount <= 0` short-circuits
    ///     to `Outcome(shouldWarn: false, usedPercent: 0)`.
    ///   - transactionsInPeriod: All transactions that fall within the
    ///     budget's current period (caller is responsible for the date filter).
    ///     This function filters out non-expense rows and rows that don't
    ///     match the budget's `categoryId` (if the budget is category-scoped).
    ///   - threshold: The warning threshold percentage, e.g. `80` for 80%.
    ///   - lastWarnedPercent: The percent at which this budget was last
    ///     warned in the current period, or `nil` if never warned this period.
    ///     `shouldWarn` returns false when a prior warning already covered
    ///     this threshold (`lastWarnedPercent >= threshold`).
    /// - Returns: The evaluation outcome.
    public static func evaluate(
        budget: Budget,
        transactionsInPeriod: [Transaction],
        threshold: Int,
        lastWarnedPercent: Int?
    ) -> Outcome {
        guard budget.amount > 0 else {
            return Outcome(shouldWarn: false, usedPercent: 0)
        }
        let totalSpent = transactionsInPeriod
            .filter { txn in
                guard txn.type == .expense else { return false }
                guard let scopedCategoryId = budget.categoryId else { return true }
                return txn.categoryId == scopedCategoryId
            }
            .reduce(into: Decimal(0)) { $0 += $1.amount }
        let ratio = (totalSpent / budget.amount * 100) as NSDecimalNumber
        let usedPercent = ratio.intValue   // truncation is intentional (conservative)
        let shouldWarn = usedPercent >= threshold
            && (lastWarnedPercent == nil || lastWarnedPercent! < threshold)
        return Outcome(shouldWarn: shouldWarn, usedPercent: usedPercent)
    }
}
