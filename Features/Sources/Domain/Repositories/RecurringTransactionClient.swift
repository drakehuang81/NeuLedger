import Foundation
import Dependencies
import DependenciesMacros

@DependencyClient
public struct RecurringTransactionClient: Sendable {
    public var fetchAll: @Sendable () async throws -> [RecurringTransaction]
    public var fetchDue: @Sendable (_ on: Date) async throws -> [RecurringTransaction]
    public var add: @Sendable (RecurringTransaction) async throws -> Void
    public var update: @Sendable (RecurringTransaction) async throws -> Void
    public var delete: @Sendable (RecurringTransaction.ID) async throws -> Void
}

extension RecurringTransactionClient: TestDependencyKey {
    public static let testValue = RecurringTransactionClient()
}

public extension DependencyValues {
    var recurringTransactionClient: RecurringTransactionClient {
        get { self[RecurringTransactionClient.self] }
        set { self[RecurringTransactionClient.self] = newValue }
    }
}
