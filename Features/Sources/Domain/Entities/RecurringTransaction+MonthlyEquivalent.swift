import Foundation

public extension RecurringTransaction {
    /// 換算成「每月等值」金額：weekly × 52 ÷ 12、monthly × 1、yearly ÷ 12。
    ///
    /// 摘要卡用這個折算，而不是只挑 `frequency == .monthly` 的範本相加——
    /// 後者是 `RecurringTransactionManagementView` 原本的做法，週繳與年繳
    /// 的範本完全不計入，所以那張卡顯示的月收／月支／淨額都偏低。
    ///
    /// 先乘後除是刻意的：`amount / 12 * 52` 會讓中間值先被 `Decimal` 的
    /// 除法捨入一次，誤差再被乘回去放大；`amount * 52 / 12` 只在最後除一次。
    var monthlyEquivalentAmount: Decimal {
        switch frequency {
        case .weekly:  return amount * 52 / 12
        case .monthly: return amount
        case .yearly:  return amount / 12
        }
    }
}
