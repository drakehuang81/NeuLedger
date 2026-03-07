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
                try databaseClient.fetch(
                    FetchDescriptor<SDAccount>(sortBy: [SortDescriptor(\.sortOrder)])
                )
            },
            fetchActive: {
                try databaseClient.fetch(
                    FetchDescriptor<SDAccount>(
                        predicate: #Predicate { $0.isArchived == false },
                        sortBy: [SortDescriptor(\.sortOrder)]
                    )
                )
            },
            computeBalance: { accountId in
                let context = databaseClient.makeContext()
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
                try databaseClient.add(account, as: SDAccount.self)
            },
            update: { account in
                let accountId = account.id
                try databaseClient.update(
                    matching: FetchDescriptor<SDAccount>(
                        predicate: #Predicate { $0.id == accountId }
                    )
                ) { existing, _ in
                    existing.name = account.name
                    existing.type = account.type.rawValue
                    existing.icon = account.icon
                    existing.color = account.color
                    existing.sortOrder = account.sortOrder
                    existing.isArchived = account.isArchived
                }
            },
            archive: { id in
                try databaseClient.update(
                    matching: FetchDescriptor<SDAccount>(
                        predicate: #Predicate { $0.id == id }
                    )
                ) { existing, _ in
                    existing.isArchived = true
                }
            },
            delete: { id in
                try databaseClient.deleteFirst(
                    matching: FetchDescriptor<SDAccount>(
                        predicate: #Predicate { $0.id == id }
                    )
                )
            }
        )
    }
}
