import Testing
import Foundation
@testable import Domain

/// 純函數測試：`Budget.evaluate(transactionsInPeriod:threshold:lastWarnedPercent:)`
/// （前身為 BudgetWarningPolicy；2026-06-05 改為 rich-entity 方法，案例語意不變。）
@Suite("Budget.evaluate")
struct BudgetEvaluateTests {

    private func makeBudget(
        amount: Decimal,
        categoryId: UUID? = nil
    ) -> Budget {
        Budget(
            id: UUID(),
            name: "Test",
            amount: amount,
            categoryId: categoryId,
            period: .monthly,
            startDate: Date(),
            isActive: true
        )
    }

    private func expense(_ amount: Decimal, categoryId: UUID? = nil) -> Transaction {
        Transaction(
            amount: amount,
            date: Date(),
            categoryId: categoryId,
            accountId: UUID().uuidString,
            type: .expense
        )
    }

    @Test("zero-amount budget returns shouldWarn=false, usedPercent=0")
    func testZeroAmountBudget() {
        let outcome = makeBudget(amount: 0).evaluate(
            transactionsInPeriod: [expense(500)],
            threshold: 80,
            lastWarnedPercent: nil
        )
        #expect(outcome == .init(shouldWarn: false, usedPercent: 0))
    }

    @Test("usedPercent below threshold does not warn")
    func testBelowThreshold() {
        let outcome = makeBudget(amount: 1000).evaluate(
            transactionsInPeriod: [expense(500)],
            threshold: 80,
            lastWarnedPercent: nil
        )
        #expect(outcome.usedPercent == 50)
        #expect(outcome.shouldWarn == false)
    }

    @Test("usedPercent at or above threshold warns when no prior warning")
    func testFirstCrossing() {
        let outcome = makeBudget(amount: 1000).evaluate(
            transactionsInPeriod: [expense(850)],
            threshold: 80,
            lastWarnedPercent: nil
        )
        #expect(outcome.usedPercent == 85)
        #expect(outcome.shouldWarn == true)
    }

    @Test("already-warned at same threshold does not re-fire")
    func testAlreadyWarned() {
        let outcome = makeBudget(amount: 1000).evaluate(
            transactionsInPeriod: [expense(900)],
            threshold: 80,
            lastWarnedPercent: 85
        )
        #expect(outcome.usedPercent == 90)
        #expect(outcome.shouldWarn == false)
    }

    @Test("warned at older lower threshold does re-fire at new threshold")
    func testThresholdRaised() {
        let outcome = makeBudget(amount: 1000).evaluate(
            transactionsInPeriod: [expense(900)],
            threshold: 80,
            lastWarnedPercent: 50
        )
        #expect(outcome.shouldWarn == true)
    }

    @Test("filters out non-expense transactions")
    func testFiltersNonExpense() {
        let income = Transaction(
            amount: 100_000,
            date: Date(),
            accountId: UUID().uuidString,
            type: .income
        )
        let transfer = Transaction(
            amount: 100_000,
            date: Date(),
            accountId: UUID().uuidString,
            toAccountId: UUID().uuidString,
            type: .transfer
        )
        let outcome = makeBudget(amount: 1000).evaluate(
            transactionsInPeriod: [income, transfer, expense(500)],
            threshold: 80,
            lastWarnedPercent: nil
        )
        #expect(outcome.usedPercent == 50)
        #expect(outcome.shouldWarn == false)
    }

    @Test("category-scoped budget only sums matching category expenses")
    func testCategoryScoped() {
        let foodCategory = UUID()
        let otherCategory = UUID()
        let outcome = makeBudget(amount: 1000, categoryId: foodCategory).evaluate(
            transactionsInPeriod: [
                expense(500, categoryId: foodCategory),
                expense(2000, categoryId: otherCategory),
            ],
            threshold: 80,
            lastWarnedPercent: nil
        )
        #expect(outcome.usedPercent == 50)
        #expect(outcome.shouldWarn == false)
    }

    @Test("unscoped budget (categoryId == nil) sums all expense rows")
    func testUnscopedSumsAll() {
        let outcome = makeBudget(amount: 1000, categoryId: nil).evaluate(
            transactionsInPeriod: [
                expense(500, categoryId: UUID()),
                expense(500, categoryId: UUID()),
            ],
            threshold: 80,
            lastWarnedPercent: nil
        )
        #expect(outcome.usedPercent == 100)
        #expect(outcome.shouldWarn == true)
    }
}
