import Domain
import Foundation

extension BudgetPeriod {
    /// Analysis 頁的期間標籤（「本週 / 本月 / 今年」語氣），沿用既有的 `analysis_period_*` key。
    ///
    /// 與 `BudgetPeriod.localizedName`（「每週 / 每月 / 每年」，預算表單用）**刻意分開**：
    /// 同一個 enum 在兩個畫面有兩種語氣，合併會讓其中一邊讀起來很怪。
    ///
    /// `bundle: .main` 不可省——Features 是 SPM target，不帶 bundle 會去查模組自己的
    /// resource bundle，而字串表放在 app target，查不到就靜默回傳 key 本身。
    var analysisLabel: String {
        switch self {
        case .weekly:  return String(localized: "analysis_period_week", bundle: .main)
        case .monthly: return String(localized: "analysis_period_month", bundle: .main)
        case .yearly:  return String(localized: "analysis_period_year", bundle: .main)
        }
    }
}
