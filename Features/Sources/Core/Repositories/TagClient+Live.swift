import Foundation
import SwiftData
import Domain
import Dependencies

/// Live implementation of `TagClient` backed by `SwiftDataStore`.
///
/// Many-to-many disassociation on delete happens inside
/// `SDTag.prepareForDelete()` (clears the inverse `transactions` array),
/// which `SwiftDataStore.delete(id:)` invokes before removing the SD instance.
extension TagClient: DependencyKey {
    public static var liveValue: TagClient {
        let store = SwiftDataStore<Tag, SDTag>()

        return TagClient(
            fetchAll: {
                try await store.fetchAll(sortBy: [SortDescriptor(\.name)])
            },
            add: { tag in
                try await store.add(tag)
            },
            update: { tag in
                try await store.update(tag)
            },
            delete: { id in
                try await store.delete(id: id)
            }
        )
    }
}
