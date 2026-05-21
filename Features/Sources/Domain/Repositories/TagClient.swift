import Foundation
import Dependencies
import DependenciesMacros

/// A client interface for managing custom transaction tags.
///
/// Use `TagClient` to administrate user-defined tags that add supplementary, multi-dimensional
/// classification to transactions across boundaries of standard categories.
@DependencyClient
public struct TagClient: Sendable {
    /// Fetches all available tags.
    ///
    /// - Returns: An array of all stored `Tag` entities.
    public var fetchAll: @Sendable () async throws -> [Tag]
    
    /// Adds a newly created tag.
    ///
    /// - Parameter tag: The `Tag` entity to persist.
    public var add: @Sendable (Tag) async throws -> Void
    
    /// Updates an existing tag.
    ///
    /// - Parameter tag: The modified `Tag` entity. Its `id` must match an existing record.
    public var update: @Sendable (Tag) async throws -> Void
    
    /// Removes a tag from the storage.
    ///
    /// - Parameter id: The unique identifier of the `Tag` to delete.
    public var delete: @Sendable (Tag.ID) async throws -> Void
}

extension TagClient: TestDependencyKey {
    public static let testValue = Self()
}

public extension DependencyValues {
    var tagClient: TagClient {
        get { self[TagClient.self] }
        set { self[TagClient.self] = newValue }
    }
}
