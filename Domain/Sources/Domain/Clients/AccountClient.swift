import Foundation
import Dependencies
import DependenciesMacros

/// A client interface for managing the user's financial accounts.
///
/// Use `AccountClient` to create, update, fetch, archive, or delete account records.
@DependencyClient
public struct AccountClient: Sendable {
    /// Fetches all accounts, including archived ones.
    ///
    /// - Returns: An array of all stored `Account` entities.
    public var fetchAll: @Sendable () async throws -> [Account]
    
    /// Fetches only the active accounts that are currently available for selection.
    ///
    /// - Returns: An array of active (unarchived) `Account` entities.
    public var fetchActive: @Sendable () async throws -> [Account]
    
    /// Computes the current balance for a specified account.
    ///
    /// - Parameter id: The unique identifier of the `Account`.
    /// - Returns: The calculated `Decimal` balance based on the account's transactions.
    public var computeBalance: @Sendable (Account.ID) async throws -> Decimal
    
    /// Adds a newly created account.
    ///
    /// - Parameter account: The `Account` entity to persist.
    public var add: @Sendable (Account) async throws -> Void
    
    /// Updates an existing account.
    ///
    /// - Parameter account: The modified `Account` entity. Its `id` must match an existing record.
    public var update: @Sendable (Account) async throws -> Void
    
    /// Archives a specified account.
    ///
    /// Archived accounts remain in the database to preserve historical transactions
    /// but are typically hidden from active selection menus.
    ///
    /// - Parameter id: The unique identifier of the `Account` to archive.
    public var archive: @Sendable (Account.ID) async throws -> Void
    
    /// Permanently removes an account and potentially its associated data.
    ///
    /// - Parameter id: The unique identifier of the `Account` to delete.
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
