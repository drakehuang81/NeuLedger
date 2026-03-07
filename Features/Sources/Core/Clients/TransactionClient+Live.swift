import Foundation
import SwiftData
import Domain
import Dependencies

/// Live implementation of `TransactionClient` backed by SwiftData.
extension TransactionClient: DependencyKey {
    public static var liveValue: TransactionClient {
        @Dependency(\.databaseClient) var databaseClient

        return TransactionClient(
            fetchRecent: {
                var descriptor = FetchDescriptor<SDTransaction>(
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                )
                descriptor.fetchLimit = 20
                return try databaseClient.fetch(descriptor)
            },
            fetchAll: {
                try databaseClient.fetch(
                    FetchDescriptor<SDTransaction>(
                        sortBy: [SortDescriptor(\.date, order: .reverse)]
                    )
                )
            },
            fetch: { filter in
                let context = databaseClient.makeContext()

                // Build base descriptor and fetch all, then filter in-memory
                // for complex multi-criteria filtering that SwiftData predicates
                // don't easily compose.
                let descriptor = FetchDescriptor<SDTransaction>(
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                )
                var results = try context.fetch(descriptor)

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
                    let rawTypes = types.map(\.rawValue)
                    results = results.filter { rawTypes.contains($0.type) }
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

                return results.map { $0.toDomain() }
            },
            search: { query in
                let context = databaseClient.makeContext()
                let lowered = query.lowercased()
                let descriptor = FetchDescriptor<SDTransaction>(
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                )
                let all = try context.fetch(descriptor)
                let filtered = all.filter {
                    $0.note?.lowercased().contains(lowered) ?? false
                }
                return filtered.map { $0.toDomain() }
            },
            add: { transaction in
                try databaseClient.add(transaction, as: SDTransaction.self)
            },
            update: { transaction in
                let txnId = transaction.id
                try databaseClient.update(
                    matching: FetchDescriptor<SDTransaction>(
                        predicate: #Predicate { $0.id == txnId }
                    )
                ) { existing, context in
                    existing.amount = transaction.amount
                    existing.date = transaction.date
                    existing.note = transaction.note
                    existing.categoryId = transaction.categoryId
                    existing.accountId = transaction.accountId
                    existing.toAccountId = transaction.toAccountId
                    existing.type = transaction.type.rawValue
                    existing.aiSuggested = transaction.aiSuggested
                    existing.updatedAt = transaction.updatedAt
                    existing.tags = transaction.tags.map { SDTag.resolve($0, context: context) }
                }
            },
            delete: { id in
                try databaseClient.deleteFirst(
                    matching: FetchDescriptor<SDTransaction>(
                        predicate: #Predicate { $0.id == id }
                    )
                )
            }
        )
    }
}
