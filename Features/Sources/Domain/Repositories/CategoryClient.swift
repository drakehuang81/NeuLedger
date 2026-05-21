import Foundation
import Dependencies
import DependenciesMacros

/// A client interface for managing transaction categories.
///
/// Use `CategoryClient` to handle the hierarchy and classification of transactions,
/// enabling fetching, adding, modifying, and deleting category distinct types.
@DependencyClient
public struct CategoryClient: Sendable {
    /// Fetches all custom and default categories.
    ///
    /// - Returns: An array of all stored `Category` entities.
    public var fetchAll: @Sendable () async throws -> [Category]
    
    /// Retrieves categories that match a specific transaction type.
    ///
    /// - Parameter type: The ``TransactionType`` to filter categories (e.g., `.income` or `.expense`).
    /// - Returns: An array of `Category` entities corresponding to the given type.
    public var fetchByType: @Sendable (TransactionType) async throws -> [Category]
    
    /// Adds a newly created category.
    ///
    /// - Parameter category: The `Category` entity to persist.
    public var add: @Sendable (Category) async throws -> Void
    
    /// Updates an existing category.
    ///
    /// - Parameter category: The modified `Category` entity. Its `id` must match an existing record.
    public var update: @Sendable (Category) async throws -> Void
    
    /// Removes a category from the storage.
    ///
    /// - Parameter id: The unique identifier of the `Category` to delete.
    public var delete: @Sendable (Category.ID) async throws -> Void
}

extension CategoryClient: TestDependencyKey {
    public static let testValue = Self()
}

public extension DependencyValues {
    var categoryClient: CategoryClient {
        get { self[CategoryClient.self] }
        set { self[CategoryClient.self] = newValue }
    }
}
