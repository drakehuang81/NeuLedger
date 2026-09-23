import Foundation
import Testing
@testable import Domain

/// 全 App 唯一的「交易屬於帳戶」與「對帳戶餘額的影響」定義。
@Suite("Transaction+Accounts / +Aggregation")
struct TransactionAccountsTests {
    private static let accA = "acc-A"
    private static let accB = "acc-B"

    private static func tx(_ amount: Decimal, _ type: TransactionType, from: String, to: String? = nil) -> Transaction {
        Transaction(amount: amount, date: Date(), accountId: from, toAccountId: to, type: type)
    }

    @Test("involves(account:) is bidirectional for transfers")
    func involves() {
        let transfer = Self.tx(500, .transfer, from: Self.accA, to: Self.accB)
        #expect(transfer.involves(account: Self.accA))
        #expect(transfer.involves(account: Self.accB))
        #expect(!transfer.involves(account: "acc-C"))
        #expect(Self.tx(100, .expense, from: Self.accA).involves(account: Self.accA))
        #expect(!Self.tx(100, .expense, from: Self.accA).involves(account: Self.accB))
    }

    @Test("signedEffect: income +, expense −, transfer out −, transfer in +, unrelated 0")
    func signedEffect() {
        #expect(Self.tx(100, .income, from: Self.accA).signedEffect(on: Self.accA) == 100)
        #expect(Self.tx(100, .expense, from: Self.accA).signedEffect(on: Self.accA) == -100)
        let transfer = Self.tx(500, .transfer, from: Self.accA, to: Self.accB)
        #expect(transfer.signedEffect(on: Self.accA) == -500)
        #expect(transfer.signedEffect(on: Self.accB) == 500)
        #expect(transfer.signedEffect(on: "acc-C") == 0)

        let selfTransfer = Self.tx(500, .transfer, from: Self.accA, to: Self.accA)
        #expect(selfTransfer.signedEffect(on: Self.accA) == 0)
        #expect(selfTransfer.involves(account: Self.accA))
    }

    @Test("total(of:) sums one type only")
    func totalOfType() {
        let list = [
            Self.tx(100, .expense, from: Self.accA),
            Self.tx(250, .expense, from: Self.accA),
            Self.tx(900, .income, from: Self.accA),
            Self.tx(400, .transfer, from: Self.accA, to: Self.accB),
        ]
        #expect(list.total(of: .expense) == 350)
        #expect(list.total(of: .income) == 900)
        #expect(list.total(of: .transfer) == 400)
    }

    @Test("balance(of:) folds signedEffect")
    func balanceOfAccount() {
        let list = [
            Self.tx(1000, .income, from: Self.accA),
            Self.tx(300, .expense, from: Self.accA),
            Self.tx(200, .transfer, from: Self.accA, to: Self.accB),
            Self.tx(50, .expense, from: Self.accB),
        ]
        #expect(list.balance(of: Self.accA) == 500)
        #expect(list.balance(of: Self.accB) == 150)
    }
}
