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
}
