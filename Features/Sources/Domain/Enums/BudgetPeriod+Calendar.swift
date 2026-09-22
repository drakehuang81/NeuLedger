import Foundation

/// 全 App 唯一的「BudgetPeriod → 日曆區間」定義。
/// Kernel / Planning / Analysis / Filter / Watch 一律呼叫這裡，不得自行 `dateInterval(of:)`。
public extension BudgetPeriod {

    /// weekly → `.weekOfYear`、monthly → `.month`、yearly → `.year`。
    var calendarComponent: Calendar.Component {
        switch self {
        case .weekly:  return .weekOfYear
        case .monthly: return .month
        case .yearly:  return .year
        }
    }

    /// 包含 `date` 的日曆對齊期間，半開區間 `[start, end)`。SwiftData predicate 用這個。
    func dateInterval(containing date: Date, calendar: Calendar = .current) -> DateInterval {
        calendar.dateInterval(of: calendarComponent, for: date)
            ?? DateInterval(start: date, duration: 0)
    }

    /// 同一期間的閉區間版本：上界 = 下一期起點減 1 毫秒。
    /// 給 `TransactionFilter.dateRange`（`ClosedRange<Date>`）使用。
    func closedRange(containing date: Date, calendar: Calendar = .current) -> ClosedRange<Date> {
        let interval = dateInterval(containing: date, calendar: calendar)
        return interval.start...interval.end.addingTimeInterval(-0.001)
    }

    /// 緊接在「包含 `date` 的期間」之前的那一期（例如「上個月」）。
    func previousInterval(before date: Date, calendar: Calendar = .current) -> DateInterval {
        let current = dateInterval(containing: date, calendar: calendar)
        return dateInterval(containing: current.start.addingTimeInterval(-1), calendar: calendar)
    }

    /// 把 `date` 往後推一個期間（週期交易的下次到期日）。
    func next(after date: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: calendarComponent, value: 1, to: date) ?? date
    }
}
