import Foundation
import SwiftData
import Domain
import Dependencies

/// Live implementation of `TransactionClient` backed by `SwiftDataStore`.
///
/// The `weeklySpending`, `statsSnapshot`, and `detailStats` endpoints
/// still delegate to `DatabaseClient` helpers — those are analytics
/// concerns that move to `AnalyticsUseCase` in Phase 5. Until then this
/// file is the only Repository Live that retains a `databaseClient`
/// dependency, and only for those three analytic endpoints.
extension TransactionClient: DependencyKey {
    public static var liveValue: TransactionClient {
        @Dependency(\.databaseClient) var databaseClient

        let store = SwiftDataStore<Transaction, SDTransaction>()

        return TransactionClient(
            fetchRecent: {
                let all = try await store.fetchAll(
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                )
                return Array(all.prefix(20))
            },
            fetchAll: {
                try await store.fetchAll(sortBy: [SortDescriptor(\.date, order: .reverse)])
            },
            fetch: { filter in
                var results = try await store.fetchAll(
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                )

                if let categoryIds = filter.categoryIds {
                    results = results.filter { txn in
                        guard let catId = txn.categoryId else { return false }
                        return categoryIds.contains(catId)
                    }
                }
                if let accountIds = filter.accountIds {
                    results = results.filter { accountIds.contains($0.accountId) }
                }
                if let tagIds = filter.tagIds {
                    results = results.filter { txn in
                        txn.tags.contains { tagIds.contains($0.id) }
                    }
                }
                if let types = filter.types {
                    results = results.filter { types.contains($0.type) }
                }
                if let dateRange = filter.dateRange {
                    results = results.filter { dateRange.contains($0.date) }
                }
                if let searchText = filter.searchText, !searchText.isEmpty {
                    let lowered = searchText.lowercased()
                    results = results.filter {
                        $0.note?.lowercased().contains(lowered) ?? false
                    }
                }
                return results
            },
            search: { query in
                let lowered = query.lowercased()
                let all = try await store.fetchAll(
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                )
                return all.filter { $0.note?.lowercased().contains(lowered) ?? false }
            },
            add: { transaction in
                try await store.add(transaction)
            },
            update: { transaction in
                try await store.update(transaction)
            },
            delete: { id in
                try await store.delete(id: id)
            },
            weeklySpending: { accountID, days in
                try databaseClient.weeklySpendingSums(accountID: accountID, days: days)
            },
            statsSnapshot: {
                try databaseClient.statsSnapshot()
            },
            detailStats: { transaction in
                try databaseClient.detailStats(for: transaction)
            }
        )
    }
}

// Budget-warning evaluation now lives in BudgetUseCase.evaluateAfterTransaction,
// invoked by LedgerUseCase.record/update under architecture.md §3.1 Scenario B
// (post-condition invariant). TransactionClient+Live is back to a pure
// Repository surface — every mutation goes straight to SwiftDataStore.
