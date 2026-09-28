import Foundation

/// A snapshot of summary spending statistics displayed in the Dashboard stats section.
public struct StatsSnapshot: Equatable, Sendable {
    public let today: Decimal
    public let week: Decimal

    /// 期間內的儲蓄率（收入減支出，除以收入）。
    ///
    /// **`nil` 表示「算不出來」，不是 0。** 期間內沒有任何收入紀錄時分母是 0，
    /// 儲蓄率沒有定義；用 `0` 當哨兵值會讓「我這週剛好收支相抵」與「我這週沒有
    /// 收入」在畫面上長得一模一樣。可以是負值——支出大於收入就是負的，那正是
    /// 最需要被看到的情況。
    public let savingsPercentage: Double?

    public init(today: Decimal, week: Decimal, savingsPercentage: Double?) {
        self.today = today
        self.week = week
        self.savingsPercentage = savingsPercentage
    }

    public static let zero = StatsSnapshot(today: 0, week: 0, savingsPercentage: nil)
}
