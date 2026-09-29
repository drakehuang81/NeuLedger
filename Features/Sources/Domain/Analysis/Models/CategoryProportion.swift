import Foundation

public struct CategoryProportion: Equatable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let amount: Decimal

    /// 未分類支出桶的固定 id；Analysis drill-down 靠它判斷「不帶 categoryIds 篩選」。
    public static let uncategorizedId = "uncategorized"

    /// 這一桶是「沒有分類的支出」的合計，不是使用者建立的分類。
    ///
    /// 給呼叫端跳過它用（例如 Dashboard 的「本月最大支出分類」）。刻意用旗標而不是
    /// 比對名稱：kernel 目前拿「—」當顯示字串，哪天有人把它 localise，或使用者真的
    /// 把某個分類命名成「—」，比對名稱就會**靜默地**失效。
    public let isUnassigned: Bool
    // Normally we'd include a color identifier or hex here, but we will simplify

    /// `isUnassigned` 擺在最後並預設 `false`，既有呼叫點不必改。
    public init(
        id: String = UUID().uuidString,
        name: String,
        amount: Decimal,
        isUnassigned: Bool = false
    ) {
        self.id = id
        self.name = name
        self.amount = amount
        self.isUnassigned = isUnassigned
    }
}
