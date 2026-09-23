import Foundation

/// 全 App 唯一的「預算已花多少」規則。Planning / Insights Kernel / Watch 一律呼叫這裡。
public extension Budget {

    /// 此預算是否計入這筆交易：只計支出；有 `categoryId` 時只計該分類。
    func appliesTo(_ transaction: Transaction) -> Bool {
        guard transaction.type == .expense else { return false }
        guard let scopedCategoryId = categoryId else { return true }
        return transaction.categoryId == scopedCategoryId
    }

    /// 已花金額。呼叫端負責先用 `period.dateInterval(containing:)` 篩出期內交易。
    func spent(in transactionsInPeriod: some Sequence<Transaction>) -> Decimal {
        transactionsInPeriod.reduce(Decimal.zero) { appliesTo($1) ? $0 + $1.amount : $0 }
    }

    /// 已用比例（0.25 = 花了 25%）；`amount <= 0` 回 `nil`。
    func progress(spent: Decimal) -> Double? {
        guard amount > 0 else { return nil }
        return NSDecimalNumber(decimal: spent / amount).doubleValue
    }
}
