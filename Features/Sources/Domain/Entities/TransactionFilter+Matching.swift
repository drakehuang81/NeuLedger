import Foundation

public extension TransactionFilter {

    /// 唯一的篩選語意。`accountIds` 採雙向（含轉入），與 `Transaction.involves(account:)` 一致。
    /// 各維度為 AND；`nil` 維度不篩；`searchText` 空字串不篩。
    func matches(_ transaction: Transaction) -> Bool {
        if let categoryIds {
            guard let categoryId = transaction.categoryId, categoryIds.contains(categoryId) else { return false }
        }
        if let accountIds {
            guard accountIds.contains(where: { transaction.involves(account: $0) }) else { return false }
        }
        if let tagIds {
            guard transaction.tags.contains(where: { tagIds.contains($0.id) }) else { return false }
        }
        if let types {
            guard types.contains(transaction.type) else { return false }
        }
        if let dateRange {
            guard dateRange.contains(transaction.date) else { return false }
        }
        if let searchText, !searchText.isEmpty {
            let lowered = searchText.lowercased()
            guard transaction.note?.lowercased().contains(lowered) == true else { return false }
        }
        return true
    }
}
