import Foundation
import SwiftData
import Domain
import Dependencies

/// Live implementation of `RecurringTransactionClient` backed by SwiftData.
extension RecurringTransactionClient: DependencyKey {
    public static var liveValue: RecurringTransactionClient {
        @Dependency(\.databaseClient) var databaseClient

        return RecurringTransactionClient(
            fetchAll: {
                try databaseClient.fetch(FetchDescriptor<SDRecurringTransaction>())
            },
            fetchDue: { on in
                try databaseClient.fetch(
                    FetchDescriptor<SDRecurringTransaction>(
                        predicate: #Predicate { $0.nextDueDate <= on }
                    )
                )
            },
            add: { rt in
                try databaseClient.add(rt, as: SDRecurringTransaction.self)
            },
            update: { rt in
                let rtId = rt.id
                try databaseClient.update(
                    matching: FetchDescriptor<SDRecurringTransaction>(
                        predicate: #Predicate { $0.id == rtId }
                    )
                ) { existing, _ in
                    existing.amount = rt.amount
                    existing.note = rt.note
                    existing.categoryId = rt.categoryId
                    existing.accountId = rt.accountId
                    existing.toAccountId = rt.toAccountId
                    existing.typeRaw = rt.type.rawValue
                    existing.tagIds = rt.tags.map(\.id)
                    existing.frequencyRaw = rt.frequency.rawValue
                    existing.nextDueDate = rt.nextDueDate
                    existing.isActive = rt.isActive
                }
            },
            delete: { id in
                try databaseClient.deleteFirst(
                    matching: FetchDescriptor<SDRecurringTransaction>(
                        predicate: #Predicate { $0.id == id }
                    )
                )
            }
        )
    }
}
