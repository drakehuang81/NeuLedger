import Foundation
import SwiftData
import Domain
import Dependencies

/// Live implementation of `TagClient` backed by SwiftData.
extension TagClient: DependencyKey {
    public static var liveValue: TagClient {
        @Dependency(\.databaseClient) var databaseClient

        return TagClient(
            fetchAll: {
                let container = databaseClient.modelContainer()
                let context = ModelContext(container)
                let descriptor = FetchDescriptor<SDTag>(
                    sortBy: [SortDescriptor(\.name)]
                )
                let results = try context.fetch(descriptor)
                return results.map { $0.toDomain() }
            },
            add: { tag in
                let container = databaseClient.modelContainer()
                let context = ModelContext(container)
                SDTag.from(tag, context: context)
                try context.save()
            },
            update: { tag in
                let container = databaseClient.modelContainer()
                let context = ModelContext(container)
                let tagId = tag.id
                let descriptor = FetchDescriptor<SDTag>(
                    predicate: #Predicate { $0.id == tagId }
                )
                guard let existing = try context.fetch(descriptor).first else {
                    throw CoreError.notFound("Tag \(tag.id)")
                }
                existing.name = tag.name
                existing.color = tag.color
                try context.save()
            },
            delete: { id in
                let container = databaseClient.modelContainer()
                let context = ModelContext(container)
                let descriptor = FetchDescriptor<SDTag>(
                    predicate: #Predicate { $0.id == id }
                )
                guard let existing = try context.fetch(descriptor).first else {
                    throw CoreError.notFound("Tag \(id)")
                }
                // SwiftData automatically handles disassociation from transactions
                // when the tag is deleted due to the @Relationship inverse.
                context.delete(existing)
                try context.save()
            }
        )
    }
}
