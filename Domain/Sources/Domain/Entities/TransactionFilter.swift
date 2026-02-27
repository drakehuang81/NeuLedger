import Foundation

/// A set of criteria deployed to narrow down a list of transactions.
///
/// Provide a `TransactionFilter` to endpoints like ``TransactionClient/fetch``
/// to efficiently retrieve subsets of transactions matching categories, accounts, timeframes, or specific text.
public struct TransactionFilter: Equatable, Sendable {
    /// A set indicating the acceptable category identifiers. If `nil`, categories are not filtered.
    public var categoryIds: Set<Category.ID>?
    
    /// A set indicating the acceptable account identifiers. If `nil`, accounts are not filtered.
    public var accountIds: Set<Account.ID>?
    
    /// A set indicating the acceptable tag identifiers. If `nil`, tags are not filtered.
    public var tagIds: Set<Tag.ID>?
    
    /// A set indicating the acceptable transaction types (e.g., only `.income`). If `nil`, types are not filtered.
    public var types: Set<TransactionType>?
    
    /// The closed time range within which the transactions must fall. If `nil`, dates are not constrained.
    public var dateRange: ClosedRange<Date>?
    
    /// A string used to match occurrences in a transaction's notes or associated textual data. If `nil`, text is not searched.
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
