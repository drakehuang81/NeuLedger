import Foundation
import Testing
import Domain
@testable import Core

@Suite("InsightCache")
struct InsightCacheTests {

    @Test("cache miss returns nil")
    func cacheMissReturnsNil() async {
        let cache = InsightCache()
        let summary = SpendingSummary(
            totalIncome: 1000,
            totalExpense: 500,
            categoryBreakdown: ["食物": 300, "交通": 200],
            periodDescription: "2026年3月"
        )
        let result = await cache.get(for: summary)
        #expect(result == nil)
    }

    @Test("cache hit returns stored value")
    func cacheHitReturnsStoredValue() async {
        let cache = InsightCache()
        let summary = SpendingSummary(
            totalIncome: 1000,
            totalExpense: 500,
            categoryBreakdown: ["食物": 500],
            periodDescription: "本週"
        )
        await cache.set("你本週消費偏高", for: summary)
        let result = await cache.get(for: summary)
        #expect(result == "你本週消費偏高")
    }

    @Test("different summaries produce different keys")
    func differentSummariesDontCollide() async {
        let cache = InsightCache()
        let summary1 = SpendingSummary(
            totalIncome: 1000, totalExpense: 500,
            categoryBreakdown: [:], periodDescription: "本月"
        )
        let summary2 = SpendingSummary(
            totalIncome: 2000, totalExpense: 1000,
            categoryBreakdown: [:], periodDescription: "本月"
        )
        await cache.set("洞察一", for: summary1)
        let result1 = await cache.get(for: summary1)
        let result2 = await cache.get(for: summary2)
        #expect(result1 == "洞察一")
        #expect(result2 == nil)
    }

    @Test("same data with different category order hits cache")
    func categoryOrderDoesNotAffectCacheKey() async {
        let cache = InsightCache()
        let summary1 = SpendingSummary(
            totalIncome: 1000, totalExpense: 500,
            categoryBreakdown: ["食物": 300, "交通": 200],
            periodDescription: "本月"
        )
        let summary2 = SpendingSummary(
            totalIncome: 1000, totalExpense: 500,
            categoryBreakdown: ["交通": 200, "食物": 300],
            periodDescription: "本月"
        )
        await cache.set("洞察", for: summary1)
        let result = await cache.get(for: summary2)
        // Keys are sorted alphabetically, so order doesn't matter
        #expect(result == "洞察")
    }
}
