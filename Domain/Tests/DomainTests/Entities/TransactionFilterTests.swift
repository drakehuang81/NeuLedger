import Foundation
import Testing
@testable import Domain

@Suite("TransactionFilter Tests")
struct TransactionFilterTests {
    @Test("TransactionFilter empty initialization defaults all nil")
    func testEmptyInitialization() {
        let filter = TransactionFilter()

        #expect(filter.categoryIds == nil)
        #expect(filter.accountIds == nil)
        #expect(filter.tagIds == nil)
        #expect(filter.types == nil)
        #expect(filter.dateRange == nil)
        #expect(filter.searchText == nil)
    }

    @Test("TransactionFilter Equatable — identical empty filters")
    func testEquatableEmpty() {
        #expect(TransactionFilter() == TransactionFilter())
    }

    @Test("TransactionFilter with searchText")
    func testSearchText() {
        let f1 = TransactionFilter(searchText: "Food")
        let f2 = TransactionFilter(searchText: "Food")
        let f3 = TransactionFilter(searchText: "Transport")

        #expect(f1 == f2)
        #expect(f1 != f3)
        #expect(f1.searchText == "Food")
    }

    @Test("TransactionFilter with categoryIds")
    func testCategoryIds() {
        let catId1 = UUID()
        let catId2 = UUID()

        let f1 = TransactionFilter(categoryIds: [catId1, catId2])
        let f2 = TransactionFilter(categoryIds: [catId1, catId2])
        let f3 = TransactionFilter(categoryIds: [catId1])

        #expect(f1 == f2)
        #expect(f1 != f3)
        #expect(f1.categoryIds?.count == 2)
    }

    @Test("TransactionFilter with accountIds")
    func testAccountIds() {
        let accId = UUID()

        let f = TransactionFilter(accountIds: [accId])
        #expect(f.accountIds?.contains(accId) == true)
        #expect(f != TransactionFilter())
    }

    @Test("TransactionFilter with tagIds")
    func testTagIds() {
        let tagId = UUID()

        let f = TransactionFilter(tagIds: [tagId])
        #expect(f.tagIds?.contains(tagId) == true)
        #expect(f != TransactionFilter())
    }

    @Test("TransactionFilter with types")
    func testTypes() {
        let f1 = TransactionFilter(types: [.expense, .income])
        let f2 = TransactionFilter(types: [.expense])

        #expect(f1 != f2)
        #expect(f1.types?.count == 2)
        #expect(f2.types?.contains(.expense) == true)
    }

    @Test("TransactionFilter with dateRange")
    func testDateRange() {
        let start = Date(timeIntervalSince1970: 0)
        let end = Date(timeIntervalSince1970: 86400)

        let f = TransactionFilter(dateRange: start...end)
        #expect(f.dateRange != nil)
        #expect(f != TransactionFilter())
    }

    @Test("TransactionFilter combined filters Equatable")
    func testCombinedFilters() {
        let catId = UUID()
        let accId = UUID()

        let f1 = TransactionFilter(
            categoryIds: [catId],
            accountIds: [accId],
            types: [.expense],
            searchText: "lunch"
        )
        let f2 = TransactionFilter(
            categoryIds: [catId],
            accountIds: [accId],
            types: [.expense],
            searchText: "lunch"
        )
        let f3 = TransactionFilter(
            categoryIds: [catId],
            accountIds: [accId],
            types: [.income],
            searchText: "lunch"
        )

        #expect(f1 == f2)
        #expect(f1 != f3)
    }
}
