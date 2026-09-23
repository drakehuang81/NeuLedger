import Foundation
import Testing
@testable import Domain

/// `TransactionFilter.matches(_:)` 是唯一的篩選語意；`accountIds` 採雙向。
@Suite("TransactionFilter.matches")
struct TransactionFilterMatchingTests {
    private static let accA = "acc-A"
    private static let accB = "acc-B"
    private static let catFood = UUID()
    private static let tagTravel = Tag(id: UUID(), name: "Travel", color: "#FFF")
    private static let day = Date(timeIntervalSince1970: 1_700_000_000)

    private static let expense = Transaction(
        amount: 100, date: day, note: "Sushi dinner", categoryId: catFood,
        accountId: accA, type: .expense, tags: [tagTravel]
    )
    private static let transferIn = Transaction(
        amount: 500, date: day, note: nil, categoryId: nil,
        accountId: accB, toAccountId: accA, type: .transfer
    )

    @Test("empty filter matches everything")
    func emptyFilter() {
        #expect(TransactionFilter().matches(Self.expense))
        #expect(TransactionFilter().matches(Self.transferIn))
    }

    @Test("accountIds includes transfers INTO the account")
    func accountIdsBidirectional() {
        let f = TransactionFilter(accountIds: [Self.accA])
        #expect(f.matches(Self.expense))
        #expect(f.matches(Self.transferIn))
        #expect(!TransactionFilter(accountIds: ["acc-C"]).matches(Self.transferIn))
    }

    @Test("categoryIds excludes uncategorized rows")
    func categoryIds() {
        let f = TransactionFilter(categoryIds: [Self.catFood])
        #expect(f.matches(Self.expense))
        #expect(!f.matches(Self.transferIn))
    }

    @Test("tagIds / types / dateRange / searchText each narrow the match")
    func otherDimensions() {
        #expect(TransactionFilter(tagIds: [Self.tagTravel.id]).matches(Self.expense))
        #expect(!TransactionFilter(tagIds: [UUID()]).matches(Self.expense))
        #expect(TransactionFilter(types: [.expense]).matches(Self.expense))
        #expect(!TransactionFilter(types: [.income]).matches(Self.expense))
        let inRange = Self.day.addingTimeInterval(-60)...Self.day.addingTimeInterval(60)
        let outRange = Self.day.addingTimeInterval(60)...Self.day.addingTimeInterval(120)
        #expect(TransactionFilter(dateRange: inRange).matches(Self.expense))
        #expect(!TransactionFilter(dateRange: outRange).matches(Self.expense))
        #expect(TransactionFilter(searchText: "DINNER").matches(Self.expense))
        #expect(!TransactionFilter(searchText: "taxi").matches(Self.expense))
        #expect(TransactionFilter(searchText: "").matches(Self.transferIn))   // 空字串不篩
    }

    @Test("dimensions are ANDed")
    func combined() {
        let f = TransactionFilter(accountIds: [Self.accA], types: [.transfer])
        #expect(f.matches(Self.transferIn))
        #expect(!f.matches(Self.expense))
    }
}
