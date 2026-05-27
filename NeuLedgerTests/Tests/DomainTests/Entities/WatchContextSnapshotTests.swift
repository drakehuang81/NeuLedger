import Foundation
import Testing
@testable import Domain

@Suite("WatchContextSnapshot Tests")
struct WatchContextSnapshotTests {

    private func makeSampleSnapshot(monthBudgetProgress: Double?) -> WatchContextSnapshot {
        let accountId = UUID()
        let category = Category(
            name: "Food",
            icon: "fork.knife",
            color: "#FF9500",
            type: .expense,
            sortOrder: 0,
            isDefault: true
        )
        let account = Account(
            id: accountId,
            name: "Cash",
            type: .cash,
            icon: "banknote",
            color: "#34C759",
            sortOrder: 0,
            isArchived: false,
            createdAt: Date(timeIntervalSince1970: 0)
        )
        return WatchContextSnapshot(
            categories: [category],
            accounts: [account],
            defaultAccountId: accountId,
            todayTotal: Decimal(350),
            todayCount: 3,
            monthBudgetProgress: monthBudgetProgress,
            snapshotAt: Date(timeIntervalSince1970: 1_000_000)
        )
    }

    @Test("encodesAndDecodes")
    func encodesAndDecodes() throws {
        let original = makeSampleSnapshot(monthBudgetProgress: 0.42)

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(WatchContextSnapshot.self, from: data)

        #expect(decoded == original)
    }

    @Test("nilBudgetProgressIsEncodedAsAbsent")
    func nilBudgetProgressIsEncodedAsAbsent() throws {
        let original = makeSampleSnapshot(monthBudgetProgress: nil)

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(WatchContextSnapshot.self, from: data)

        #expect(decoded.monthBudgetProgress == nil)
        #expect(decoded == original)
    }
}
