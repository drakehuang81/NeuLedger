import Foundation
import Dependencies
import DependenciesMacros

@DependencyClient
public struct CategoryClient: Sendable {
    public var fetchAll: @Sendable () async throws -> [Category]
    public var fetchByType: @Sendable (TransactionType) async throws -> [Category]
    public var add: @Sendable (Category) async throws -> Void
    public var update: @Sendable (Category) async throws -> Void
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
