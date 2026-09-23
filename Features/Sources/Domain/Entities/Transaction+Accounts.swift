import Foundation

/// 全 App 唯一的「交易 ↔ 帳戶」規則。餘額、帳戶篩選、Dashboard 範圍、刪帳戶保護一律用這裡。
public extension Transaction {

    /// 交易是否牽涉此帳戶：轉出方 `accountId` 或轉入方 `toAccountId`。
    func involves(account id: Account.ID) -> Bool {
        accountId == id || toAccountId == id
    }

    /// 此交易對指定帳戶餘額的淨影響：收入 +、支出 −、轉帳轉出 −、轉入 +；無關帳戶為 0。
    func signedEffect(on id: Account.ID) -> Decimal {
        switch type {
        case .income:
            return accountId == id ? amount : 0
        case .expense:
            return accountId == id ? -amount : 0
        case .transfer:
            var effect: Decimal = 0
            if accountId == id { effect -= amount }
            if toAccountId == id { effect += amount }
            return effect
        }
    }
}
