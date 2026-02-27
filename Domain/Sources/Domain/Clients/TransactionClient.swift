import Foundation
import Dependencies
import DependenciesMacros

@DependencyClient
public struct TransactionClient: Sendable {
    public var fetchRecent: @Sendable () async throws -> [Transaction]
    public var fetchAll: @Sendable () async throws -> [Transaction]
    public var fetch: @Sendable (TransactionFilter) async throws -> [Transaction]
    public var search: @Sendable (String) async throws -> [Transaction]
    public var add: @Sendable (Transaction) async throws -> Void
    public var update: @Sendable (Transaction) async throws -> Void
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
