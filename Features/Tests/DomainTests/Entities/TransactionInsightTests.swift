import Foundation
import Testing
@testable import Domain

@Suite("TransactionInsight Tests")
struct TransactionInsightTests {

    @Test("Same kinds are equal")
    func testEquatableSameKind() {
        let a = TransactionInsight(kind: .transfer(monthCount: 2, monthTotal: 5500))
        let b = TransactionInsight(kind: .transfer(monthCount: 2, monthTotal: 5500))
        #expect(a == b)
    }

    @Test("Different kinds are not equal")
    func testEquatableDifferentKind() {
        let a = TransactionInsight(kind: .transfer(monthCount: 2, monthTotal: 5500))
        let b = TransactionInsight(kind: .fallback(monthlyCategoryCount: 5))
        #expect(a != b)
    }

    @Test("Insight is Sendable across actor boundary")
    func testSendable() async {
        let insight = TransactionInsight(kind: .fallback(monthlyCategoryCount: 1))
        await Task.detached { _ = insight }.value
    }

    @Test("incomeVsLast same payload equals; different payload not equal")
    func testIncomeVsLastEquality() {
        let a = TransactionInsight(kind: .incomeVsLast(percentDelta: 4.2, lastAmount: 48_000, monthlyCount: 1, netMonth: 47_830))
        let b = TransactionInsight(kind: .incomeVsLast(percentDelta: 4.2, lastAmount: 48_000, monthlyCount: 1, netMonth: 47_830))
        let c = TransactionInsight(kind: .incomeVsLast(percentDelta: 5.0, lastAmount: 48_000, monthlyCount: 1, netMonth: 47_830))
        #expect(a == b)
        #expect(a != c)
    }

    @Test("expenseVsCategoryAvg same payload equals; different payload not equal")
    func testExpenseVsCategoryAvgEquality() {
        let a = TransactionInsight(kind: .expenseVsCategoryAvg(percentDelta: -10.0, avg: 182, monthlyCount: 12, monthTotal: 2_184))
        let b = TransactionInsight(kind: .expenseVsCategoryAvg(percentDelta: -10.0, avg: 182, monthlyCount: 12, monthTotal: 2_184))
        let c = TransactionInsight(kind: .expenseVsCategoryAvg(percentDelta: -10.0, avg: 200, monthlyCount: 12, monthTotal: 2_184))
        #expect(a == b)
        #expect(a != c)
    }
}
