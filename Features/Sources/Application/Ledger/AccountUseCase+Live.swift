import Foundation
import Dependencies
import Domain

extension AccountUseCase: DependencyKey {
    public static var liveValue: AccountUseCase {
        @Dependency(\.accountClient) var accountClient

        return AccountUseCase(
            create: { try await accountClient.add($0) },
            update: { try await accountClient.update($0) },
            archive: { try await accountClient.archive($0) },
            unarchive: { id in
                // AccountClient currently has no explicit unarchive endpoint
                // (the Repository was designed for the archive direction only).
                // unarchive flips the isArchived flag back to false via update;
                // fetch first to retain other fields untouched.
                let all = try await accountClient.fetchAll()
                guard var existing = all.first(where: { $0.id == id }) else {
                    throw CoreError.notFound("Account")
                }
                existing.isArchived = false
                try await accountClient.update(existing)
            },
            delete: { try await accountClient.delete($0) },
            listAll: { try await accountClient.fetchAll() },
            listActive: { try await accountClient.fetchActive() },
            balances: {
                let active = try await accountClient.fetchActive()
                var result: [Account.ID: Decimal] = [:]
                for account in active {
                    result[account.id] = try await accountClient.computeBalance(account.id)
                }
                return result
            }
        )
    }
}
