import Foundation

/// 一則洞察的**結構化**內容:種類 + 算好的數字,不含任何使用者可見字串。
///
/// 字串與金額格式化刻意留在 Features 層:承載 `InsightsClient` 實作的
/// `Core` target 只依賴 `Domain`,碰不到 `Common` 的 `twdFormatted`
/// 也碰不到 main bundle 的 localization(`Features/Package.swift:73-87`)。
/// 把字串寫死在 Application 層正是 audit B9 的結構性成因。
public struct InsightDescriptor: Equatable, Identifiable, Sendable {
    public enum Kind: Equatable, Sendable {
        /// 本月支出最高的分類:名稱、金額、占本月總支出的比例(0...1)。
        case topCategory(name: String, amount: Decimal, share: Double)
        /// 本月儲蓄率(可為負)。
        case savingsRate(Double)
        /// 本週支出總額。
        case weekSpending(Decimal)
    }

    public let id: UUID
    public let kind: Kind

    public init(id: UUID = UUID(), kind: Kind) {
        self.id = id
        self.kind = kind
    }
}
