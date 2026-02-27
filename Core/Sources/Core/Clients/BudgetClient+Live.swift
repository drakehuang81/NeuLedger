import Foundation
import SwiftData
import Domain
import Dependencies

/// Live implementation of `BudgetClient` backed by SwiftData.
extension BudgetClient: @retroactive DependencyKey {
    public static var liveValue: BudgetClient {
        @Dependency(\.databaseClient) var databaseClient

        return BudgetClient(
            fetchAll: {
                let container = databaseClient.modelContainer()
                let context = ModelContext(container)
                let descriptor = FetchDescriptor<SDBudget>()
                let results = try context.fetch(descriptor)
                return results.map { $0.toDomain() }
            },
            fetchActive: {
                let container = databaseClient.modelContainer()
                let context = ModelContext(container)
                let descriptor = FetchDescriptor<SDBudget>(
                    predicate: #Predicate { $0.isActive == true }
                )
                let results = try context.fetch(descriptor)
                return results.map { $0.toDomain() }
            },
            add: { budget in
                let container = databaseClient.modelContainer()
                let context = ModelContext(container)
                SDBudget.from(budget, context: context)
                try context.save()
            },
            update: { budget in
                let container = databaseClient.modelContainer()
                let context = ModelContext(container)
                let budgetId = budget.id
                let descriptor = FetchDescriptor<SDBudget>(
                    predicate: #Predicate { $0.id == budgetId }
                )
                guard let existing = try context.fetch(descriptor).first else {
                    throw CoreError.notFound("Budget \(budget.id)")
                }
                existing.name = budget.name
                existing.amount = budget.amount
                existing.categoryId = budget.categoryId
                existing.period = budget.period.rawValue
                existing.startDate = budget.startDate
                existing.isActive = budget.isActive
                try context.save()
            },
            delete: { id in
                let container = databaseClient.modelContainer()
                let context = ModelContext(container)
                let descriptor = FetchDescriptor<SDBudget>(
                    predicate: #Predicate { $0.id == id }
                )
                guard let existing = try context.fetch(descriptor).first else {
                    throw CoreError.notFound("Budget \(id)")
                }
                context.delete(existing)
                try context.save()
            }
        )
    }
}
