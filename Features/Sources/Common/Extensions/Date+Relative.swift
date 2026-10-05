import Foundation

public extension Date {
    /// 從 self 到 other 的日曆天數（只看日期、不看時刻；過去為負）。
    ///
    /// 以 `startOfDay` 對齊兩端再算差，所以 23:00 到隔天 01:00 算 1 天而不是
    /// 0 天——「還有幾天到期」這種標籤要的是日曆天數，不是經過的時數。
    func days(until other: Date, calendar: Calendar = .current) -> Int {
        let from = calendar.startOfDay(for: self)
        let to = calendar.startOfDay(for: other)
        return calendar.dateComponents([.day], from: from, to: to).day ?? 0
    }
}
