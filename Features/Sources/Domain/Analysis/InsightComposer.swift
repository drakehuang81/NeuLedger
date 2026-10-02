import Foundation

/// 純函式:把 `SpendingSummary` 挑選成一組 `InsightDescriptor`。
///
/// 不吃依賴、不碰時間、不碰 IO——只讀 `SpendingSummary` 現有欄位,算出
/// 「哪一種洞察 + 算好的數字」。字串與金額格式化留給 Features 層
/// (見 `InsightDescriptor` 的註解)。
///
/// 沒有資料就回傳 `[]`,不補任何預設卡片——這正是 audit B9 要移除的
/// 「回傳三筆寫死假資料」的行為。
public enum InsightComposer {
    public static func compose(from summary: SpendingSummary) -> [InsightDescriptor] {
        var descriptors: [InsightDescriptor] = []

        // topCategory:monthTotal == 0 時沒有比例可言,直接不產生——避免除以零。
        if let name = summary.topCategoryName,
           let amount = summary.topCategoryAmount,
           amount > 0,
           summary.monthTotal > 0 {
            let share = (amount as NSDecimalNumber).doubleValue / (summary.monthTotal as NSDecimalNumber).doubleValue
            descriptors.append(InsightDescriptor(kind: .topCategory(name: name, amount: amount, share: share)))
        }

        // savingsRate:只有 `nil`(沒有收入紀錄、算不出來)才略過。負值必須照樣產生
        // 描述子——入不敷出正是最該被看到的情況;恰好 0 也照樣產生,那代表「收支
        // 相抵」,是一個真實的結果,不是沒資料。
        if let rate = summary.savingsPercentage {
            descriptors.append(InsightDescriptor(kind: .savingsRate(rate)))
        }

        if summary.weekTotal > 0 {
            descriptors.append(InsightDescriptor(kind: .weekSpending(summary.weekTotal)))
        }

        return descriptors
    }
}
