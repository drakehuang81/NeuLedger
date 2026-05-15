import Testing
import Foundation
@testable import Domain

@Suite("InsightData")
struct InsightDataTests {
    @Test("Equality respects all stored fields when id matches")
    func testEquality() {
        let a = InsightData(title: "T", body: "B", metric: "+10%", metricColor: .income)
        let b = InsightData(id: a.id, title: "T", body: "B", metric: "+10%", metricColor: .income)
        #expect(a == b)
    }

    @Test("Different id makes values unequal")
    func testInequalityById() {
        let a = InsightData(title: "T", body: "B", metric: "+10%", metricColor: .income)
        let b = InsightData(title: "T", body: "B", metric: "+10%", metricColor: .income)
        #expect(a != b)
    }

    @Test("InsightColor has 4 cases")
    func testColorCases() {
        #expect(InsightColor.allCases.count == 4)
    }
}
