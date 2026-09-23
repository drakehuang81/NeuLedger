import Foundation
import Testing
@testable import Domain

/// `Budget+Spending`：全 App 唯一的「預算已花多少」定義。
@Suite("Budget+Spending")
struct BudgetSpendingTests {
    private static let food = UUID()
    private static let transport = UUID()

    private static func budget(amount: Decimal, categoryId: UUID? = nil) -> Budget {
        Budget(name: "B", amount: amount, categoryId: categoryId, period: .monthly, startDate: Date())
    }
    private static func tx(_ amount: Decimal, _ type: TransactionType, category: UUID?) -> Transaction {
        Transaction(amount: amount, date: Date(), categoryId: category, accountId: "acc", type: type)
    }

    private static let sample: [Transaction] = [
        tx(100, .expense, category: food),
        tx(250, .expense, category: transport),
        tx(30,  .expense, category: nil),
        tx(900, .income,  category: food),
        tx(400, .transfer, category: nil),
    ]

    @Test("appliesTo: expense only; category-scoped budget only its category")
    func appliesTo() {
        let overall = Self.budget(amount: 1000)
        let foodOnly = Self.budget(amount: 1000, categoryId: Self.food)
        #expect(overall.appliesTo(Self.tx(1, .expense, category: nil)))
        #expect(!overall.appliesTo(Self.tx(1, .income, category: nil)))
        #expect(!overall.appliesTo(Self.tx(1, .transfer, category: nil)))
        #expect(foodOnly.appliesTo(Self.tx(1, .expense, category: Self.food)))
        #expect(!foodOnly.appliesTo(Self.tx(1, .expense, category: Self.transport)))
        #expect(!foodOnly.appliesTo(Self.tx(1, .expense, category: nil)))
    }

    @Test("spent(in:) sums applicable expenses only")
    func spent() {
        #expect(Self.budget(amount: 1000).spent(in: Self.sample) == 380)
        #expect(Self.budget(amount: 1000, categoryId: Self.food).spent(in: Self.sample) == 100)
        #expect(Self.budget(amount: 1000).spent(in: []) == 0)
    }

    @Test("progress(spent:) is spent/amount, nil for non-positive amount")
    func progress() {
        #expect(Self.budget(amount: 1000).progress(spent: 250) == 0.25)
        #expect(Self.budget(amount: 0).progress(spent: 250) == nil)
        #expect(Self.budget(amount: -5).progress(spent: 0) == nil)
    }

    @Test("evaluate uses spent(in:) — same usedPercent as manual sum")
    func evaluateConsistent() {
        let outcome = Self.budget(amount: 1000).evaluate(
            transactionsInPeriod: Self.sample, threshold: 30, lastWarnedPercent: nil
        )
        #expect(outcome.usedPercent == 38)
        #expect(outcome.shouldWarn)
    }
}
