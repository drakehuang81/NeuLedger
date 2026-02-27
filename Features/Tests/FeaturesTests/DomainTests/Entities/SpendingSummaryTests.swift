import Foundation
import Testing
@testable import Domain

@Suite("SpendingSummary Tests")
struct SpendingSummaryTests {
    @Test("SpendingSummary Initialization and Equatable")
    func testInitializationAndEquatable() {
        let sum1 = SpendingSummary(
            totalIncome: 5000,
            totalExpense: 2000,
            categoryBreakdown: ["Food": 1000, "Transport": 1000],
            periodDescription: "January 2026"
        )
        
        let sum2 = SpendingSummary(
            totalIncome: 5000,
            totalExpense: 2000,
            categoryBreakdown: ["Food": 1000, "Transport": 1000],
            periodDescription: "January 2026"
        )
        
        let sum3 = SpendingSummary(
            totalIncome: 6000,
            totalExpense: 1500,
            categoryBreakdown: ["Food": 1500],
            periodDescription: "February 2026"
        )
        
        #expect(sum1 == sum2)
        #expect(sum1 != sum3)
        #expect(sum1.totalIncome == 5000)
        #expect(sum1.totalExpense == 2000)
        #expect(sum1.categoryBreakdown["Food"] == 1000)
        #expect(sum1.periodDescription == "January 2026")
    }
}
