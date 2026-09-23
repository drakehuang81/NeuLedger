import Foundation
import Testing
@testable import Domain

@Suite("RecurringTransaction")
struct RecurringTransactionTests {

    private static var utcCalendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private static func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        utcCalendar.date(from: DateComponents(year: y, month: m, day: d, hour: 9))!
    }

    private static func template(
        frequency: BudgetPeriod = .monthly,
        nextDueDate: Date,
        anchorDate: Date? = nil
    ) -> RecurringTransaction {
        RecurringTransaction(
            id: UUID(), amount: 18_000, note: "rent",
            categoryId: nil, accountId: UUID().uuidString, toAccountId: nil,
            type: .expense, tags: [], frequency: frequency,
            nextDueDate: nextDueDate, isActive: true, createdAt: nextDueDate,
            anchorDate: anchorDate
        )
    }

    @Test("anchorDate defaults to nil so existing call sites keep compiling")
    func testAnchorDateDefaultsToNil() {
        let t = Self.template(nextDueDate: Self.date(2026, 1, 31))
        #expect(t.anchorDate == nil)
    }

    @Test("nextDate uses the anchored series when anchorDate is set")
    func testNextDateUsesAnchor() {
        let anchor = Self.date(2026, 1, 31)
        let t = Self.template(nextDueDate: Self.date(2026, 2, 28), anchorDate: anchor)
        #expect(t.nextDate(after: t.nextDueDate, calendar: Self.utcCalendar) == Self.date(2026, 3, 31))
    }

    @Test("nextDate keeps the legacy drifting behaviour when anchorDate is nil")
    func testNextDateWithoutAnchorKeepsLegacyBehaviour() {
        let t = Self.template(nextDueDate: Self.date(2026, 2, 28))
        #expect(t.nextDate(after: t.nextDueDate, calendar: Self.utcCalendar) == Self.date(2026, 3, 28))
    }
}
