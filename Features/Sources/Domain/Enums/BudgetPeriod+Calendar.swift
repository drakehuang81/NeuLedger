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
        let upper = interval.end.addingTimeInterval(-0.001)
        // 防禦 `dateInterval` 的零長度 fallback：確保 lowerBound <= upperBound（退化為單一時刻）。
        return interval.start...max(interval.start, upper)
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

    /// 以 `anchor` 為系列起點，回傳第一個嚴格大於 `date` 的到期日。
    ///
    /// 一律用「anchor + n 期」計算，**不是**從上一次（可能已被月份長度 clamp 的）
    /// 結果再往後加一期，所以 1/31 的月繳系列是 1/31 → 2/28 → 3/31 → 4/30 → 5/31，
    /// 不會像 `next(after:)` 那樣一旦被 clamp 成 28 就永遠停在 28（health-audit A10）。
    func occurrence(after date: Date, anchoredAt anchor: Date, calendar: Calendar = .current) -> Date {
        guard anchor <= date else { return anchor }

        let component = calendarComponent
        // 先估算已經過了幾期，再往後找第一個嚴格大於 date 的系列日期。
        // clamp（例如 1/31 → 2/28）會讓 dateComponents 少算一期，所以要留修正空間。
        let elapsed = calendar.dateComponents([component], from: anchor, to: date).value(for: component) ?? 0
        var step = max(elapsed, 0)

        for _ in 0..<4 {
            step += 1
            if let candidate = calendar.date(byAdding: component, value: step, to: anchor), candidate > date {
                return candidate
            }
        }

        // 理論上到不了這裡；真的到了就退回舊行為，保證回傳值仍然大於 date。
        return next(after: date, calendar: calendar)
    }
}
