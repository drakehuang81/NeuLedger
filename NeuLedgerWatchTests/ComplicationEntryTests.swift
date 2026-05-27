import Foundation
import Testing
import Domain
@testable import WatchFeatures

@Suite("ComplicationEntry Tests")
struct ComplicationEntryTests {

    @Test("Display amount formats Decimal as integer with no decimals")
    func displayAmountInteger() {
        let entry = ComplicationEntry(
            date: Date(),
            todayTotal: 480,
            todayCount: 2,
            monthBudgetProgress: nil
        )
        #expect(entry.displayAmount == "480")
    }

    @Test("Display amount uses thousand separators")
    func displayAmountThousandSeparator() {
        let entry = ComplicationEntry(
            date: Date(),
            todayTotal: 12_500,
            todayCount: 3,
            monthBudgetProgress: nil
        )
        #expect(entry.displayAmount == "12,500")
    }

    @Test("placeholder() returns dash-display safe defaults")
    func placeholderIsDashSafe() {
        let entry = ComplicationEntry.placeholder
        #expect(entry.todayTotal == 0)
        #expect(entry.todayCount == 0)
        #expect(entry.monthBudgetProgress == nil)
    }
}
