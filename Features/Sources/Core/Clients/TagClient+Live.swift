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
                try databaseClient.fetch(
                    FetchDescriptor<SDTag>(sortBy: [SortDescriptor(\.name)])
                )
            },
            add: { tag in
                try databaseClient.add(tag, as: SDTag.self)
            },
            update: { tag in
                let tagId = tag.id
                try databaseClient.update(
                    matching: FetchDescriptor<SDTag>(
                        predicate: #Predicate { $0.id == tagId }
                    )
                ) { existing, _ in
                    existing.name = tag.name
                    existing.color = tag.color
                }
            },
            delete: { id in
                try databaseClient.deleteFirst(
                    matching: FetchDescriptor<SDTag>(
                        predicate: #Predicate { $0.id == id }
                    )
                )
            }
        )
    }
}
