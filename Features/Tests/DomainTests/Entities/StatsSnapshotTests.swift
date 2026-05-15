import Testing
import Foundation
@testable import Domain

@Suite("StatsSnapshot")
struct StatsSnapshotTests {
    @Test(".zero has all zero values")
    func testZero() {
        #expect(StatsSnapshot.zero.today == 0)
        #expect(StatsSnapshot.zero.week == 0)
        #expect(StatsSnapshot.zero.savingsPercentage == 0)
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
