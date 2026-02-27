import Foundation
import Dependencies
import DependenciesMacros

@DependencyClient
public struct BudgetClient: Sendable {
    public var fetchAll: @Sendable () async throws -> [Budget]
    public var fetchActive: @Sendable () async throws -> [Budget]
    public var add: @Sendable (Budget) async throws -> Void
    public var update: @Sendable (Budget) async throws -> Void
    public var delete: @Sendable (Budget.ID) async throws -> Void
}

extension BudgetClient: TestDependencyKey {
    public static let testValue = Self()
}

public extension DependencyValues {
    var budgetClient: BudgetClient {
        get { self[BudgetClient.self] }
        set { self[BudgetClient.self] = newValue }
    }
}
