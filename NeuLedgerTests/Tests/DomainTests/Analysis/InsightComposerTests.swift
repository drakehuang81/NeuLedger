import Foundation
import Testing
@testable import Domain

/// 把 `Kind` 映成一個穩定、易讀的標籤,只用來比較「順序」——
/// 用整個陣列比對而非逐一 index 取值,數量變動時失敗訊息才好讀。
private func label(_ kind: InsightDescriptor.Kind) -> String {
    switch kind {
    case .topCategory: return "topCategory"
    case .savingsRate: return "savingsRate"
    case .weekSpending: return "weekSpending"
    }
}

@Suite("InsightComposer")
struct InsightComposerTests {
    @Test("the top spending category becomes a descriptor carrying its real share")
    func testTopCategoryDescriptor() {
        let summary = SpendingSummary(
            monthTotal: 20_000, weekTotal: 3_000,
            topCategoryName: "餐飲", topCategoryAmount: 8_400,
            savingsPercentage: 0.28
        )
        let out = InsightComposer.compose(from: summary)
        let top = out.compactMap { if case let .topCategory(name, amount, share) = $0.kind { return (name, amount, share) } else { return nil } }.first
        #expect(top?.0 == "餐飲")
        #expect(top?.1 == 8_400)
        // 8400 / 20000 = 0.42 —— 這個比例必須是算出來的,不是傳進來的
        #expect(top.map { abs($0.2 - 0.42) < 0.0001 } == true)
    }

    @Test("a summary with no activity produces no descriptors")
    func testEmptySummaryProducesNothing() {
        let out = InsightComposer.compose(from: SpendingSummary(monthTotal: 0, weekTotal: 0))
        #expect(out.isEmpty, "一筆帳都沒有時不得憑空產生洞察——那正是本 PR 要移除的行為")
    }

    @Test("monthTotal of zero never divides by zero")
    func testZeroMonthTotalDoesNotProduceAShare() {
        let summary = SpendingSummary(
            monthTotal: 0, weekTotal: 0,
            topCategoryName: "餐飲", topCategoryAmount: 500
        )
        let out = InsightComposer.compose(from: summary)
        let shares = out.compactMap { if case let .topCategory(_, _, share) = $0.kind { return share } else { return nil } }
        #expect(shares.isEmpty, "monthTotal 為 0 時沒有比例可言,不得產生 topCategory 描述子")
        // 不另外檢查 isFinite——上面 isEmpty 已經涵蓋「根本不會產生 share」,
        // 沒有 share 就沒有 inf/nan 可言,額外檢查會是對空集合的死斷言。
    }

    @Test("descriptors are ordered topCategory, savingsRate, weekSpending when all three apply")
    func testDescriptorOrder() {
        // 洞察卡片是可左右滑的 carousel,順序變動是使用者直接看得到的——
        // 這裡餵一個三種描述子都會產生的 summary,釘住固定順序。
        let summary = SpendingSummary(
            monthTotal: 20_000, weekTotal: 3_000,
            topCategoryName: "餐飲", topCategoryAmount: 8_400,
            savingsPercentage: 0.28
        )
        let out = InsightComposer.compose(from: summary)
        let labels = out.map { label($0.kind) }
        #expect(labels == ["topCategory", "savingsRate", "weekSpending"])
    }

    @Test("the savings descriptor carries the real percentage, negative included")
    func testSavingsDescriptor() {
        let positive = InsightComposer.compose(from: SpendingSummary(
            monthTotal: 10_000, weekTotal: 1_000, savingsPercentage: 0.28
        ))
        let rate = positive.compactMap { if case let .savingsRate(r) = $0.kind { return r } else { return nil } }.first
        #expect(rate.map { abs($0 - 0.28) < 0.0001 } == true)

        // 負儲蓄率（花得比賺得多）必須照樣產生描述子,不得被門檻吃掉——
        // 那正是使用者最需要看到的一則。
        let negative = InsightComposer.compose(from: SpendingSummary(
            monthTotal: 10_000, weekTotal: 1_000, savingsPercentage: -0.15
        ))
        let negRate = negative.compactMap { if case let .savingsRate(r) = $0.kind { return r } else { return nil } }.first
        #expect(negRate.map { abs($0 + 0.15) < 0.0001 } == true, "負儲蓄率不得被過濾掉")
    }
}
