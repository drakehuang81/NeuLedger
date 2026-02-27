import Foundation
import SwiftData
import Domain
import Dependencies

/// Live implementation of `AccountClient` backed by SwiftData.
extension AccountClient: DependencyKey {
    public static var liveValue: AccountClient {
        @Dependency(\.databaseClient) var databaseClient

        return AccountClient(
            fetchAll: {
                let container = databaseClient.modelContainer()
                let context = ModelContext(container)
                let descriptor = FetchDescriptor<SDAccount>(
                    sortBy: [SortDescriptor(\.sortOrder)]
                )
                let results = try context.fetch(descriptor)
                return results.map { $0.toDomain() }
            },
            fetchActive: {
                let container = databaseClient.modelContainer()
                let context = ModelContext(container)
                let descriptor = FetchDescriptor<SDAccount>(
                    predicate: #Predicate { $0.isArchived == false },
                    sortBy: [SortDescriptor(\.sortOrder)]
                )
                let results = try context.fetch(descriptor)
                return results.map { $0.toDomain() }
            },
            computeBalance: { accountId in
                let container = databaseClient.modelContainer()
                let context = ModelContext(container)
                let descriptor = FetchDescriptor<SDTransaction>(
                    predicate: #Predicate {
                        $0.accountId == accountId || $0.toAccountId == accountId
                    }
                )
                let transactions = try context.fetch(descriptor)

                var balance: Decimal = 0
                for txn in transactions {
                    let txnType = TransactionType(rawValue: txn.type) ?? .expense
                    switch txnType {
                    case .income:
                        if txn.accountId == accountId { balance += txn.amount }
                    case .expense:
                        if txn.accountId == accountId { balance -= txn.amount }
                    case .transfer:
                        if txn.accountId == accountId { balance -= txn.amount }
                        if txn.toAccountId == accountId { balance += txn.amount }
                    }
                }
                return balance
            },
            add: { account in
                let container = databaseClient.modelContainer()
                let context = ModelContext(container)
                SDAccount.from(account, context: context)
                try context.save()
            },
            update: { account in
                let container = databaseClient.modelContainer()
                let context = ModelContext(container)
                let accountId = account.id
                let descriptor = FetchDescriptor<SDAccount>(
                    predicate: #Predicate { $0.id == accountId }
                )
                guard let existing = try context.fetch(descriptor).first else {
                    throw CoreError.notFound("Account \(account.id)")
                }
                existing.name = account.name
                existing.type = account.type.rawValue
                existing.icon = account.icon
                existing.color = account.color
                existing.sortOrder = account.sortOrder
                existing.isArchived = account.isArchived
                try context.save()
            },
            archive: { id in
                let container = databaseClient.modelContainer()
                let context = ModelContext(container)
                let descriptor = FetchDescriptor<SDAccount>(
                    predicate: #Predicate { $0.id == id }
                )
                guard let existing = try context.fetch(descriptor).first else {
                    throw CoreError.notFound("Account \(id)")
                }
                existing.isArchived = true
                try context.save()
            },
            delete: { id in
                let container = databaseClient.modelContainer()
                let context = ModelContext(container)
                let descriptor = FetchDescriptor<SDAccount>(
                    predicate: #Predicate { $0.id == id }
                )
                guard let existing = try context.fetch(descriptor).first else {
                    throw CoreError.notFound("Account \(id)")
                }
                context.delete(existing)
                try context.save()
            }
        )
    }
}
