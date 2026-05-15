import Foundation

/// An insight derived from a single transaction's surrounding context.
///
/// Computed client-side (no FoundationModels call) by aggregating
/// same-category / same-type transactions in the current month.
public struct TransactionInsight: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        /// Income compared with the most recent prior same-category income.
        case incomeVsLast(percentDelta: Double, lastAmount: Decimal, monthlyCount: Int, netMonth: Decimal)
        /// Expense compared with same-category monthly average.
        case expenseVsCategoryAvg(percentDelta: Double, avg: Decimal, monthlyCount: Int, monthTotal: Decimal)
        /// Transfer — shows monthly transfer activity.
        case transfer(monthCount: Int, monthTotal: Decimal)
        /// Anything we couldn't fit into the above three.
        case fallback(monthlyCategoryCount: Int)
    }

    public let kind: Kind

    public init(kind: Kind) {
        self.kind = kind
    }
}
