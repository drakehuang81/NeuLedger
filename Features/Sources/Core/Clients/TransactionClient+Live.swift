import Foundation
import SwiftData
import Domain
import Dependencies

/// Live implementation of `TransactionClient` backed by `SwiftDataStore`.
///
/// The `weeklySpending`, `statsSnapshot`, and `detailStats` endpoints are
/// thin wrappers that re-use the same SwiftData-fetch helpers
/// `AnalyticsUseCase+Live` uses. They remain on `TransactionClient`'s
/// surface during Phase 5 so callsites that still inject
/// `@Dependency(\.transactionClient)` keep working; Phase 6 batch-switches
/// them to `\.analyticsUseCase` and these three methods come off the
/// interface entirely.
extension TransactionClient: DependencyKey {
    public static var liveValue: TransactionClient {
        // Stats endpoints reach the container via DatabaseClient rather
        // than `\.modelContainer` directly — architecture.md §4.2 reserves
        // `@Dependency(\.modelContainer)` for `SwiftDataStore` only.
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
                try TransactionAnalyticsKernel.weeklySpending(
                    accountID: accountID,
                    days: days,
                    container: databaseClient.modelContainer()
                )
            },
            statsSnapshot: {
                try TransactionAnalyticsKernel.statsSnapshot(
                    referenceDate: Date(),
                    container: databaseClient.modelContainer()
                )
            },
            detailStats: { transaction in
                try TransactionAnalyticsKernel.detailStats(
                    for: transaction,
                    container: databaseClient.modelContainer()
                )
            }
        )
    }
}

// Budget-warning evaluation now lives in BudgetUseCase.evaluateAfterTransaction,
// invoked by LedgerUseCase.record/update under architecture.md §3.1 Scenario B
// (post-condition invariant). TransactionClient+Live is back to a pure
// Repository surface — every mutation goes straight to SwiftDataStore.
