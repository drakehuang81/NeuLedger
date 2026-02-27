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
                let container = databaseClient.modelContainer()
                let context = ModelContext(container)
                var descriptor = FetchDescriptor<SDTransaction>(
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                )
                descriptor.fetchLimit = 20
                let results = try context.fetch(descriptor)
                return results.map { $0.toDomain() }
            },
            fetchAll: {
                let container = databaseClient.modelContainer()
                let context = ModelContext(container)
                let descriptor = FetchDescriptor<SDTransaction>(
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                )
                let results = try context.fetch(descriptor)
                return results.map { $0.toDomain() }
            },
            fetch: { filter in
                let container = databaseClient.modelContainer()
                let context = ModelContext(container)

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
                let container = databaseClient.modelContainer()
                let context = ModelContext(container)
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
                let container = databaseClient.modelContainer()
                let context = ModelContext(container)
                SDTransaction.from(transaction, context: context)
                try context.save()
            },
            update: { transaction in
                let container = databaseClient.modelContainer()
                let context = ModelContext(container)
                let txnId = transaction.id
                let descriptor = FetchDescriptor<SDTransaction>(
                    predicate: #Predicate { $0.id == txnId }
                )
                guard let existing = try context.fetch(descriptor).first else {
                    throw CoreError.notFound("Transaction \(transaction.id)")
                }
                existing.amount = transaction.amount
                existing.date = transaction.date
                existing.note = transaction.note
                existing.categoryId = transaction.categoryId
                existing.accountId = transaction.accountId
                existing.toAccountId = transaction.toAccountId
                existing.type = transaction.type.rawValue
                existing.aiSuggested = transaction.aiSuggested
                existing.updatedAt = transaction.updatedAt
                // Resolve tags
                existing.tags = transaction.tags.map { SDTag.resolve($0, context: context) }
                try context.save()
            },
            delete: { id in
                let container = databaseClient.modelContainer()
                let context = ModelContext(container)
                let descriptor = FetchDescriptor<SDTransaction>(
                    predicate: #Predicate { $0.id == id }
                )
                guard let existing = try context.fetch(descriptor).first else {
                    throw CoreError.notFound("Transaction \(id)")
                }
                context.delete(existing)
                try context.save()
            }
        )
    }
}
