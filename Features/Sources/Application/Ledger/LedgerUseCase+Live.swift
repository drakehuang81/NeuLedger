import Foundation
import Dependencies
import Domain

extension LedgerUseCase: DependencyKey {
    public static var liveValue: LedgerUseCase {
        @Dependency(\.transactionClient) var transactionClient
        @Dependency(\.budgetUseCase) var budgetUseCase
        @Dependency(\.categoryClient) var categoryClient
        @Dependency(\.accountClient) var accountClient

        // Shared enrichment helper — Domain join from id → resolved
        // entity. Categories and accounts are fetched once per call so
        // listAll / search return enriched rows in O(N) Swift-side.
        let enrich: @Sendable ([Transaction]) async throws -> [EnrichedTransaction] = { [categoryClient, accountClient] transactions in
            guard !transactions.isEmpty else { return [] }
            async let allCategories = categoryClient.fetchAll()
            async let allAccounts = accountClient.fetchAll()
            let categories = try await allCategories
            let accounts = try await allAccounts
            let categoryById = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
            let accountById = Dictionary(uniqueKeysWithValues: accounts.map { ($0.id, $0) })
            return transactions.map { tx in
                EnrichedTransaction(
                    transaction: tx,
                    category: tx.categoryId.flatMap { categoryById[$0] },
                    account: accountById[tx.accountId],
                    toAccount: tx.toAccountId.flatMap { accountById[$0] }
                )
            }
        }

        return LedgerUseCase(
            record: { transaction in
                try await transactionClient.add(transaction)
                // INVARIANT (architecture.md §3.1 Scenario B): every recorded
                // transaction must be evaluated for budget warnings. Cannot
                // rely on individual callers to remember.
                await budgetUseCase.evaluateAfterTransaction(transaction)
            },
            update: { transaction in
                try await transactionClient.update(transaction)
                // INVARIANT: same as record — an updated amount can push a
                // budget past its threshold just like a new transaction can.
                await budgetUseCase.evaluateAfterTransaction(transaction)
            },
            delete: { id in
                try await transactionClient.delete(id)
                // No budget-warning evaluation on delete — deletions can
                // only lower spending, never cross an upward threshold.
                // Matches the pre-LedgerUseCase behavior in
                // TransactionClient+Live, which also skipped this.
            },
            fetch: { id in
                let all = try await transactionClient.fetchAll()
                guard let match = all.first(where: { $0.id == id }) else { return nil }
                let enriched = try await enrich([match])
                return enriched.first
            },
            listRecent: { limit in
                let all = try await transactionClient.fetchAll()
                let trimmed = Array(all.prefix(max(0, limit)))
                return try await enrich(trimmed)
            },
            listAll: { filter in
                let rows = try await transactionClient.fetch(filter)
                return try await enrich(rows)
            },
            search: { query in
                let rows = try await transactionClient.search(query)
                return try await enrich(rows)
            }
        )
    }
}
