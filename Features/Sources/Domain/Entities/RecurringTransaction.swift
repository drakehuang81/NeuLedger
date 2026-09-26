import Foundation

public struct RecurringTransaction: Identifiable, Equatable, Hashable, Sendable, Codable {
    public var id: UUID
    public var amount: Decimal
    public var note: String?
    public var categoryId: Category.ID?
    public var accountId: Account.ID
    public var toAccountId: Account.ID?   // transfers only
    public var type: TransactionType
    public var tags: [Tag]
    public var frequency: BudgetPeriod    // .weekly / .monthly / .yearly
    public var nextDueDate: Date
    public var isActive: Bool
    public var createdAt: Date

    /// 系列錨點 = 使用者設定的到期日（建立或編輯時寫入）。
    /// 推進到期日時一律用 `anchor + n 期` 計算，避免月底被 clamp 後累積漂移
    /// （health-audit A10）。`nil` 代表舊資料尚未回填；從 store 讀出來的範本
    /// 一定非 nil（mapper 用 `nextDueDate` 回填）。
    public var anchorDate: Date?

    public init(
        id: UUID, amount: Decimal, note: String?,
        categoryId: Category.ID?, accountId: Account.ID,
        toAccountId: Account.ID?, type: TransactionType,
        tags: [Tag], frequency: BudgetPeriod,
        nextDueDate: Date, isActive: Bool, createdAt: Date,
        anchorDate: Date? = nil
    ) {
        self.id = id; self.amount = amount; self.note = note
        self.categoryId = categoryId; self.accountId = accountId
        self.toAccountId = toAccountId; self.type = type
        self.tags = tags; self.frequency = frequency
        self.nextDueDate = nextDueDate; self.isActive = isActive
        self.createdAt = createdAt; self.anchorDate = anchorDate
    }

    /// Returns the next due date after `base` according to `frequency`.
    ///
    /// 有錨點就走錨定系列（不漂移）；沒有錨點是尚未回填的舊資料，維持舊行為。
    public func nextDate(after base: Date, calendar: Calendar = .current) -> Date {
        guard let anchorDate else {
            return frequency.next(after: base, calendar: calendar)
        }
        return frequency.occurrence(after: base, anchoredAt: anchorDate, calendar: calendar)
    }
}
