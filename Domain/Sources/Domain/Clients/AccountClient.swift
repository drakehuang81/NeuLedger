import Foundation
import Dependencies
import DependenciesMacros

@DependencyClient
public struct AccountClient: Sendable {
    public var fetchAll: @Sendable () async throws -> [Account]
    public var fetchActive: @Sendable () async throws -> [Account]
    public var computeBalance: @Sendable (Account.ID) async throws -> Decimal
    public var add: @Sendable (Account) async throws -> Void
    public var update: @Sendable (Account) async throws -> Void
    public var archive: @Sendable (Account.ID) async throws -> Void
    public var delete: @Sendable (Account.ID) async throws -> Void
}

extension AccountClient: TestDependencyKey {
    public static let testValue = Self()
}

public extension DependencyValues {
    var accountClient: AccountClient {
        get { self[AccountClient.self] }
        set { self[AccountClient.self] = newValue }
    }
}
