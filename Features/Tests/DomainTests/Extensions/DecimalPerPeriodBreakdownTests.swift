import Foundation
import Testing
@testable import Domain

@Suite("Decimal.perPeriodBreakdown Tests")
struct DecimalPerPeriodBreakdownTests {

    @Test("Zero returns nil")
    func testZeroReturnsNil() {
        #expect(Decimal(0).perPeriodBreakdown(.monthly) == nil)
    }

    @Test("Negative returns nil")
    func testNegativeReturnsNil() {
        #expect(Decimal(-100).perPeriodBreakdown(.monthly) == nil)
    }

    @Test("Monthly NT$8000 yields per-day and per-week breakdown")
    func testMonthlyBreakdown() throws {
        let s = try #require(Decimal(8000).perPeriodBreakdown(.monthly))
        #expect(s.contains("267"))
        #expect(s.contains("1,848") || s.contains("1848"))
    }

    @Test("Weekly NT$2100 yields per-day breakdown")
    func testWeeklyBreakdown() throws {
        let s = try #require(Decimal(2100).perPeriodBreakdown(.weekly))
        #expect(s.contains("300"))
    }

    @Test("Yearly NT$120000 yields per-month breakdown")
    func testYearlyBreakdown() throws {
        let s = try #require(Decimal(120_000).perPeriodBreakdown(.yearly))
        #expect(s.contains("10,000") || s.contains("10000"))
    }

    @Test("Large monthly value rounds cleanly without crash")
    func testLargeMonthly() throws {
        let s = try #require(Decimal(999_999).perPeriodBreakdown(.monthly))
        #expect(!s.isEmpty)
    }
}
