import Foundation
import SwiftData
import Domain
import Dependencies

/// Live implementation of `CategoryClient` backed by SwiftData.
extension CategoryClient: @retroactive DependencyKey {
    public static var liveValue: CategoryClient {
        @Dependency(\.databaseClient) var databaseClient

        return CategoryClient(
            fetchAll: {
                let container = databaseClient.modelContainer()
                let context = ModelContext(container)
                let descriptor = FetchDescriptor<SDCategory>(
                    sortBy: [SortDescriptor(\.sortOrder)]
                )
                let results = try context.fetch(descriptor)
                return results.map { $0.toDomain() }
            },
            fetchByType: { type in
                let container = databaseClient.modelContainer()
                let context = ModelContext(container)
                let typeRaw = type.rawValue
                let descriptor = FetchDescriptor<SDCategory>(
                    predicate: #Predicate { $0.type == typeRaw },
                    sortBy: [SortDescriptor(\.sortOrder)]
                )
                let results = try context.fetch(descriptor)
                return results.map { $0.toDomain() }
            },
            add: { category in
                let container = databaseClient.modelContainer()
                let context = ModelContext(container)
                SDCategory.from(category, context: context)
                try context.save()
            },
            update: { category in
                let container = databaseClient.modelContainer()
                let context = ModelContext(container)
                let categoryId = category.id
                let descriptor = FetchDescriptor<SDCategory>(
                    predicate: #Predicate { $0.id == categoryId }
                )
                guard let existing = try context.fetch(descriptor).first else {
                    throw CoreError.notFound("Category \(category.id)")
                }
                existing.name = category.name
                existing.icon = category.icon
                existing.color = category.color
                existing.type = category.type.rawValue
                existing.sortOrder = category.sortOrder
                existing.isDefault = category.isDefault
                try context.save()
            },
            delete: { id in
                let container = databaseClient.modelContainer()
                let context = ModelContext(container)
                let descriptor = FetchDescriptor<SDCategory>(
                    predicate: #Predicate { $0.id == id }
                )
                guard let existing = try context.fetch(descriptor).first else {
                    throw CoreError.notFound("Category \(id)")
                }
                guard !existing.isDefault else {
                    throw CoreError.operationDenied("Cannot delete default category '\(existing.name)'")
                }
                context.delete(existing)
                try context.save()
            }
        )
    }
}
