import Foundation
import SwiftData
import Domain
import Dependencies

/// Live implementation of `BudgetClient` backed by `SwiftDataStore`.
extension BudgetClient: DependencyKey {
    public static var liveValue: BudgetClient {
        let store = SwiftDataStore<Budget, SDBudget>()

        return BudgetClient(
            fetchAll: {
                try await store.fetchAll()
            },
            fetchActive: {
                try await store.fetchAll().filter { $0.isActive }
            },
            add: { budget in
                try await store.add(budget)
            },
            update: { budget in
                try await store.update(budget)
            },
            delete: { id in
                try await store.delete(id: id)
            }
        )
    }
}
