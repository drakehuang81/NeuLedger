import Foundation
import SwiftData
import Domain
import Dependencies

/// Live implementation of `CategoryClient` backed by SwiftData.
extension CategoryClient: DependencyKey {
    public static var liveValue: CategoryClient {
        @Dependency(\.databaseClient) var databaseClient

        return CategoryClient(
            fetchAll: {
                try databaseClient.fetch(
                    FetchDescriptor<SDCategory>(sortBy: [SortDescriptor(\.sortOrder)])
                )
            },
            fetchByType: { type in
                let typeRaw = type.rawValue
                return try databaseClient.fetch(
                    FetchDescriptor<SDCategory>(
                        predicate: #Predicate { $0.type == typeRaw },
                        sortBy: [SortDescriptor(\.sortOrder)]
                    )
                )
            },
            add: { category in
                try databaseClient.add(category, as: SDCategory.self)
            },
            update: { category in
                let categoryId = category.id
                try databaseClient.update(
                    matching: FetchDescriptor<SDCategory>(
                        predicate: #Predicate { $0.id == categoryId }
                    )
                ) { existing, _ in
                    existing.name = category.name
                    existing.icon = category.icon
                    existing.color = category.color
                    existing.type = category.type.rawValue
                    existing.sortOrder = category.sortOrder
                    existing.isDefault = category.isDefault
                }
            },
            delete: { id in
                try databaseClient.deleteFirst(
                    matching: FetchDescriptor<SDCategory>(
                        predicate: #Predicate { $0.id == id }
                    ),
                    validation: { existing in
                        guard !existing.isDefault else {
                            throw CoreError.operationDenied("Cannot delete default category '\(existing.name)'")
                        }
                    }
                )
            }
        )
    }
}
