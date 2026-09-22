import Foundation
import Testing
@testable import Domain

/// `BudgetPeriod+Calendar`：全 App 唯一的「期間 → 日期區間」定義。
@Suite("BudgetPeriod+Calendar")
struct BudgetPeriodCalendarTests {

    /// 固定 gregorian + 台北時區 + 週一起算，避免機器設定影響。
    private static var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Taipei")!
        cal.firstWeekday = 2
        return cal
    }

    private static func d(_ y: Int, _ m: Int, _ day: Int, _ h: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: day, hour: h))!
    }

    @Test("calendarComponent maps weekly/monthly/yearly")
    func calendarComponent() {
        #expect(BudgetPeriod.weekly.calendarComponent == .weekOfYear)
        #expect(BudgetPeriod.monthly.calendarComponent == .month)
        #expect(BudgetPeriod.yearly.calendarComponent == .year)
    }

    @Test("monthly interval is [1st 00:00, next 1st 00:00)")
    func monthlyInterval() {
        let i = BudgetPeriod.monthly.dateInterval(containing: Self.d(2026, 1, 15), calendar: Self.calendar)
        #expect(i.start == Self.d(2026, 1, 1, 0))
        #expect(i.end == Self.d(2026, 2, 1, 0))
    }

    @Test("weekly interval starts on firstWeekday and spans 7 days")
    func weeklyInterval() {
        // 2026-01-15 是週四；firstWeekday = 2（週一）→ 起點 2026-01-12
        let i = BudgetPeriod.weekly.dateInterval(containing: Self.d(2026, 1, 15), calendar: Self.calendar)
        #expect(i.start == Self.d(2026, 1, 12, 0))
        #expect(i.duration == 7 * 86_400)
    }

    @Test("yearly interval is [Jan 1, next Jan 1)")
    func yearlyInterval() {
        let i = BudgetPeriod.yearly.dateInterval(containing: Self.d(2026, 6, 30), calendar: Self.calendar)
        #expect(i.start == Self.d(2026, 1, 1, 0))
        #expect(i.end == Self.d(2027, 1, 1, 0))
    }

    @Test("closedRange keeps the whole last day and excludes the next period's first instant")
    func closedRangeBounds() {
        let r = BudgetPeriod.monthly.closedRange(containing: Self.d(2026, 1, 15), calendar: Self.calendar)
        #expect(r.lowerBound == Self.d(2026, 1, 1, 0))
        #expect(r.contains(Self.d(2026, 1, 31, 23)))
        #expect(!r.contains(Self.d(2026, 2, 1, 0)))
    }

    @Test("previousInterval(before:) is the immediately preceding period")
    func previousInterval() {
        let p = BudgetPeriod.monthly.previousInterval(before: Self.d(2026, 1, 15), calendar: Self.calendar)
        #expect(p.start == Self.d(2025, 12, 1, 0))
        #expect(p.end == Self.d(2026, 1, 1, 0))
    }

    @Test("next(after:) adds exactly one period (month-end clamps)")
    func nextAfter() {
        #expect(BudgetPeriod.weekly.next(after: Self.d(2026, 1, 15), calendar: Self.calendar) == Self.d(2026, 1, 22))
        #expect(BudgetPeriod.monthly.next(after: Self.d(2026, 1, 31), calendar: Self.calendar) == Self.d(2026, 2, 28))
        #expect(BudgetPeriod.yearly.next(after: Self.d(2026, 1, 15), calendar: Self.calendar) == Self.d(2027, 1, 15))
    }

    @Test("RecurringTransaction.nextDate delegates to frequency.next(after:)")
    func recurringDelegates() {
        let template = RecurringTransaction(
            id: UUID(), amount: 100, note: nil, categoryId: nil,
            accountId: UUID().uuidString, toAccountId: nil, type: .expense,
            tags: [], frequency: .weekly, nextDueDate: Self.d(2026, 1, 15),
            isActive: true, createdAt: Self.d(2026, 1, 1)
        )
        let expected = BudgetPeriod.weekly.next(after: Self.d(2026, 1, 15), calendar: Self.calendar)
        #expect(template.nextDate(after: Self.d(2026, 1, 15), calendar: Self.calendar) == expected)
    }
}
