import Foundation
import Testing
@testable import Domain

@Suite("BudgetPeriod.localizedSuffix Tests")
struct BudgetPeriodSuffixTests {

    @Test("weekly returns localized week suffix (zh-Hant)")
    func testWeeklySuffix() {
        let s = BudgetPeriod.weekly.localizedSuffix
        #expect(s == "週" || s == "week")
        #expect(!s.isEmpty)
    }

    @Test("monthly returns localized month suffix")
    func testMonthlySuffix() {
        let s = BudgetPeriod.monthly.localizedSuffix
        #expect(s == "月" || s == "month")
        #expect(!s.isEmpty)
    }

    @Test("yearly returns localized year suffix")
    func testYearlySuffix() {
        let s = BudgetPeriod.yearly.localizedSuffix
        #expect(s == "年" || s == "year")
        #expect(!s.isEmpty)
    }

    @Test("all cases produce non-empty suffix")
    func testAllCasesNonEmpty() {
        for p in BudgetPeriod.allCases {
            #expect(!p.localizedSuffix.isEmpty)
        }
    }
}
