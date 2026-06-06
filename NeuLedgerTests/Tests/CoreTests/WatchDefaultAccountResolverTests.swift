import Foundation
import Testing
import SwiftData
import Dependencies
import Domain
@testable import Core

@Suite("WatchDefaultAccountResolver Tests")
struct WatchDefaultAccountResolverTests {

    private static func account(
        id: String,
        sortOrder: Int,
        isArchived: Bool = false
    ) -> Account {
        Account(
            id: id,
            name: "Account \(sortOrder)",
            type: .cash,
            icon: "banknote",
            color: "#34C759",
            sortOrder: sortOrder,
            isArchived: isArchived,
            createdAt: Date(timeIntervalSince1970: 0)
        )
    }

    /// Builds a fresh in-memory container seeded with the supplied accounts,
    /// mirroring `WatchContextBuilderTests.makeSeededContainer`.
    private func makeSeededContainer(accounts: [Account]) async throws -> ModelContainer {
        let schema = Schema([
            SDTransaction.self,
            SDAccount.self,
            SDCategory.self,
            SDBudget.self,
            SDTag.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])

        try await withDependencies {
            $0.modelContainer = container
        } operation: {
            let accountStore = AccountStore()
            for account in accounts { try await accountStore.add(account) }
        }

        return container
    }

    private func resolve(
        stored: Account.ID?,
        accounts: [Account]
    ) async throws -> Account.ID? {
        let container = try await makeSeededContainer(accounts: accounts)
        return try await withDependencies {
            $0.modelContainer = container
        } operation: {
            try await WatchDefaultAccountResolver.resolve(stored: stored)
        }
    }

    @Test("A stored id pointing to a live account is honored")
    func storedAliveIsHonored() async throws {
        let resolved = try await resolve(
            stored: "card-id",
            accounts: [
                Self.account(id: "cash-id", sortOrder: 0),
                Self.account(id: "card-id", sortOrder: 1),
            ]
        )
        #expect(resolved == "card-id")
    }

    @Test("A stored id pointing to an archived account falls back to the first active account")
    func storedArchivedFallsBack() async throws {
        let resolved = try await resolve(
            stored: "card-id",
            accounts: [
                Self.account(id: "cash-id", sortOrder: 0),
                Self.account(id: "card-id", sortOrder: 1, isArchived: true),
            ]
        )
        #expect(resolved == "cash-id")
    }

    @Test("A stored id pointing to a deleted account falls back to the first active account")
    func storedDeletedFallsBack() async throws {
        let resolved = try await resolve(
            stored: "gone-id",
            accounts: [
                Self.account(id: "cash-id", sortOrder: 0),
                Self.account(id: "card-id", sortOrder: 1),
            ]
        )
        #expect(resolved == "cash-id")
    }

    @Test("With no stored override the sortOrder-first active account wins, skipping archived ones")
    func nilStoredResolvesFirstActive() async throws {
        let resolved = try await resolve(
            stored: nil,
            accounts: [
                Self.account(id: "old-id", sortOrder: 0, isArchived: true),
                Self.account(id: "cash-id", sortOrder: 1),
                Self.account(id: "card-id", sortOrder: 2),
            ]
        )
        #expect(resolved == "cash-id")
    }

    @Test("With no active account at all the resolver returns nil even when an id is stored")
    func noActiveAccountsResolvesNil() async throws {
        let resolved = try await resolve(
            stored: "gone-id",
            accounts: [
                Self.account(id: "old-id", sortOrder: 0, isArchived: true),
            ]
        )
        #expect(resolved == nil)
    }
}
