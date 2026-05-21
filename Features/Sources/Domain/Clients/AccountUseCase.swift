import Foundation
import Dependencies
import DependenciesMacros

/// Application-layer use case for account aggregate.
///
/// Surface follows `docs/architecture.md` §5 Ledger Context. The Live
/// implementation is a thin delegation to `AccountClient` (Repository)
/// today; future business rules (e.g., automatic archive-on-delete
/// fallback) live here without changing Repository.
@DependencyClient
public struct AccountUseCase: Sendable {
    public var create: @Sendable (_ account: Account) async throws -> Void
    public var update: @Sendable (_ account: Account) async throws -> Void
    public var archive: @Sendable (_ id: Account.ID) async throws -> Void
    public var unarchive: @Sendable (_ id: Account.ID) async throws -> Void
    public var delete: @Sendable (_ id: Account.ID) async throws -> Void
    public var listAll: @Sendable () async throws -> [Account]
    public var listActive: @Sendable () async throws -> [Account]
    public var balances: @Sendable () async throws -> [Account.ID: Decimal]
}

extension AccountUseCase: TestDependencyKey {
    public static let testValue = Self()
}

public extension DependencyValues {
    var accountUseCase: AccountUseCase {
        get { self[AccountUseCase.self] }
        set { self[AccountUseCase.self] = newValue }
    }
}
