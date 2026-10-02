import Testing
import Foundation
@testable import Domain

@Suite("StatsSnapshot")
struct StatsSnapshotTests {
    @Test(".zero 的金額是 0，儲蓄率是 nil（不是 0）")
    func testZero() {
        #expect(StatsSnapshot.zero.today == 0)
        #expect(StatsSnapshot.zero.week == 0)
        // `.zero` 是「還沒有資料」的佔位值。金額 0 說得通，儲蓄率 0 不行——
        // 那會被畫面讀成「你一毛都沒存下來」，而實際上是還沒算。
        #expect(StatsSnapshot.zero.savingsPercentage == nil)
    }

    @Test("Equality respects all fields")
    func testEquality() {
        let a = StatsSnapshot(today: 100, week: 500, savingsPercentage: 0.2)
        let b = StatsSnapshot(today: 100, week: 500, savingsPercentage: 0.2)
        let c = StatsSnapshot(today: 100, week: 500, savingsPercentage: 0.3)
        #expect(a == b)
        #expect(a != c)
    }
}
