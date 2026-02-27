import Foundation

public struct TransactionFilter: Equatable, Sendable {
    public var categoryIds: Set<Category.ID>?
    public var accountIds: Set<Account.ID>?
    public var tagIds: Set<Tag.ID>?
    public var types: Set<TransactionType>?
    public var dateRange: ClosedRange<Date>?
    public var searchText: String?
    
    public init(
        categoryIds: Set<Category.ID>? = nil,
        accountIds: Set<Account.ID>? = nil,
        tagIds: Set<Tag.ID>? = nil,
        types: Set<TransactionType>? = nil,
        dateRange: ClosedRange<Date>? = nil,
        searchText: String? = nil
    ) {
        self.categoryIds = categoryIds
        self.accountIds = accountIds
        self.tagIds = tagIds
        self.types = types
        self.dateRange = dateRange
        self.searchText = searchText
    }
}
