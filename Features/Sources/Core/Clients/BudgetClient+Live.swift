import Foundation
import SwiftData
import Domain
import Dependencies

/// Live implementation of `BudgetClient` backed by SwiftData.
extension BudgetClient: DependencyKey {
    public static var liveValue: BudgetClient {
        @Dependency(\.databaseClient) var databaseClient

        return BudgetClient(
            fetchAll: {
                try databaseClient.fetch(FetchDescriptor<SDBudget>())
            },
            fetchActive: {
                try databaseClient.fetch(
                    FetchDescriptor<SDBudget>(
                        predicate: #Predicate { $0.isActive == true }
                    )
                )
            },
            add: { budget in
                try databaseClient.add(budget, as: SDBudget.self)
            },
            update: { budget in
                let budgetId = budget.id
                try databaseClient.update(
                    matching: FetchDescriptor<SDBudget>(
                        predicate: #Predicate { $0.id == budgetId }
                    )
                ) { existing, _ in
                    existing.name = budget.name
                    existing.amount = budget.amount
                    existing.categoryId = budget.categoryId
                    existing.period = budget.period.rawValue
                    existing.startDate = budget.startDate
                    existing.isActive = budget.isActive
                }
            },
            delete: { id in
                try databaseClient.deleteFirst(
                    matching: FetchDescriptor<SDBudget>(
                        predicate: #Predicate { $0.id == id }
                    )
                )
            }
        )
    }
}
