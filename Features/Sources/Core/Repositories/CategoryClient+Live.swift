import Foundation
import SwiftData
import Domain
import Dependencies

/// Live implementation of `CategoryClient` backed by `SwiftDataStore`.
extension CategoryClient: DependencyKey {
    public static var liveValue: CategoryClient {
        let store = SwiftDataStore<Domain.Category, SDCategory>()

        return CategoryClient(
            fetchAll: {
                try await store.fetchAll(sortBy: [SortDescriptor(\.sortOrder)])
            },
            fetchByType: { type in
                try await store.fetchAll(sortBy: [SortDescriptor(\.sortOrder)])
                    .filter { $0.type == type }
            },
            add: { category in
                try await store.add(category)
            },
            update: { category in
                try await store.update(category)
            },
            delete: { id in
                guard let existing = try await store.fetch(id: id) else {
                    throw CoreError.notFound("SDCategory")
                }
                guard !existing.isDefault else {
                    throw CoreError.operationDenied(
                        "Cannot delete default category '\(existing.name)'"
                    )
                }
                try await store.delete(id: id)
            }
        )
    }
}
