import Foundation

public extension Sequence where Element == Transaction {

    /// 指定類型的金額總和；其他類型不計。
    func total(of type: TransactionType) -> Decimal {
        reduce(Decimal.zero) { $1.type == type ? $0 + $1.amount : $0 }
    }

    /// 指定帳戶的餘額（`signedEffect(on:)` 的總和）。
    func balance(of accountId: Account.ID) -> Decimal {
        reduce(Decimal.zero) { $0 + $1.signedEffect(on: accountId) }
    }
}
