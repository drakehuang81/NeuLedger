import Foundation
import SwiftData
import Domain
import Dependencies

/// Live implementation of `RecurringTransactionClient` backed by `SwiftDataStore`.
extension RecurringTransactionClient: DependencyKey {
    public static var liveValue: RecurringTransactionClient {
        let store = SwiftDataStore<RecurringTransaction, SDRecurringTransaction>()

        return RecurringTransactionClient(
            fetchAll: {
                try await store.fetchAll()
            },
            fetchDue: { on in
                try await store.fetchAll().filter { $0.nextDueDate <= on && $0.isActive }
            },
            add: { rt in
                try await store.add(rt)
            },
            update: { rt in
                try await store.update(rt)
            },
            delete: { id in
                try await store.delete(id: id)
            }
        )
    }
}
