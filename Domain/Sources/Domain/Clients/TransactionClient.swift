import Foundation
import Dependencies
import DependenciesMacros

/// A client interface for managing the user's transaction records.
///
/// Use `TransactionClient` to fetch, search, filter, and mutate financial transactions.
/// This client acts as the central point for persisting and retrieving all income, expense, and transfer records.
@DependencyClient
public struct TransactionClient: Sendable {
    /// Fetches a list of the most recent transactions, typically used for dashboard views.
    ///
    /// - Returns: An array of recent `Transaction` entities.
    public var fetchRecent: @Sendable () async throws -> [Transaction]
    
    /// Fetches all stored transactions without any filtering.
    ///
    /// - Returns: An array containing every `Transaction` entity in the system.
    public var fetchAll: @Sendable () async throws -> [Transaction]
    
    /// Retrieves transactions that match the specified filtering criteria.
    ///
    /// - Parameter filter: A `TransactionFilter` value defining the constraints (such as date ranges, accounts, or categories).
    /// - Returns: An array of `Transaction` entities that satisfy the given filter.
    public var fetch: @Sendable (TransactionFilter) async throws -> [Transaction]
    
    /// Searches for transactions containing the specified keyword in their notes, categories, or tags.
    ///
    /// - Parameter query: The text to search for.
    /// - Returns: An array of `Transaction` entities matching the search text.
    public var search: @Sendable (String) async throws -> [Transaction]
    
    /// Adds a newly created transaction.
    ///
    /// - Parameter transaction: The `Transaction` entity to persist.
    public var add: @Sendable (Transaction) async throws -> Void
    
    /// Updates an existing transaction.
    ///
    /// - Parameter transaction: The modified `Transaction` entity. Its `id` must match an existing record.
    public var update: @Sendable (Transaction) async throws -> Void
    
    /// Removes a transaction from the storage.
    ///
    /// - Parameter id: The unique identifier of the `Transaction` to delete.
    public var delete: @Sendable (Transaction.ID) async throws -> Void
}

extension TransactionClient: TestDependencyKey {
    public static let testValue = Self()
}

public extension DependencyValues {
    var transactionClient: TransactionClient {
        get { self[TransactionClient.self] }
        set { self[TransactionClient.self] = newValue }
    }
}
