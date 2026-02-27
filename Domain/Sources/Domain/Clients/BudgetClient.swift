import Foundation
import Dependencies
import DependenciesMacros

/// A client interface for managing user-defined budgets.
///
/// Use `BudgetClient` to govern the financial goals set by the user, providing methods
/// to retrieve current active budgets or make alterations to budget definitions.
@DependencyClient
public struct BudgetClient: Sendable {
    /// Fetches all budget records, including past or inactive ones.
    ///
    /// - Returns: An array of all stored `Budget` entities.
    public var fetchAll: @Sendable () async throws -> [Budget]
    
    /// Fetches budgets that are currently active for the ongoing period.
    ///
    /// - Returns: An array of active `Budget` entities.
    public var fetchActive: @Sendable () async throws -> [Budget]
    
    /// Adds a newly created budget.
    ///
    /// - Parameter budget: The `Budget` entity to persist.
    public var add: @Sendable (Budget) async throws -> Void
    
    /// Updates an existing budget.
    ///
    /// - Parameter budget: The modified `Budget` entity. Its `id` must match an existing record.
    public var update: @Sendable (Budget) async throws -> Void
    
    /// Removes a budget from the storage.
    ///
    /// - Parameter id: The unique identifier of the `Budget` to delete.
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
