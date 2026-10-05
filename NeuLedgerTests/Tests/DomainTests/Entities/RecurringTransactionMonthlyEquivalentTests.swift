import Foundation
import Testing
@testable import Domain

@Suite("RecurringTransaction.monthlyEquivalentAmount")
struct RecurringTransactionMonthlyEquivalentTests {
    private static func rt(_ amount: Decimal, _ frequency: BudgetPeriod) -> RecurringTransaction {
        RecurringTransaction(
            id: UUID(), amount: amount, note: nil, categoryId: nil,
            accountId: "acc", toAccountId: nil, type: .expense, tags: [],
            frequency: frequency, nextDueDate: Date(), isActive: true, createdAt: Date()
        )
    }

    @Test("monthly is identity")
    func monthly() { #expect(Self.rt(1500, .monthly).monthlyEquivalentAmount == 1500) }

    @Test("weekly × 52 ÷ 12")
    func weekly() { #expect(Self.rt(120, .weekly).monthlyEquivalentAmount == 520) }

    @Test("yearly ÷ 12")
    func yearly() { #expect(Self.rt(12_000, .yearly).monthlyEquivalentAmount == 1000) }

    /// Multiplying before dividing matters: `120 / 12 * 52` would round the
    /// intermediate on amounts that do not divide cleanly, while
    /// `120 * 52 / 12` keeps the error to the single final division.
    @Test("non-divisible amounts stay close to the exact value")
    func rounding() {
        let weekly = Self.rt(100, .weekly).monthlyEquivalentAmount
        // 100 × 52 ÷ 12 = 433.33…
        #expect(weekly > 433)
        #expect(weekly < 434)
    }
}
