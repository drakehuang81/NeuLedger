import Foundation
import Dependencies
import DependenciesMacros

@DependencyClient
public struct TagClient: Sendable {
    public var fetchAll: @Sendable () async throws -> [Tag]
    public var add: @Sendable (Tag) async throws -> Void
    public var update: @Sendable (Tag) async throws -> Void
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
