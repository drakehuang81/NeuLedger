import Foundation
import SwiftData
import Domain
import Dependencies

/// Live implementation of `CarrierRepository` backed by `SwiftDataStore`.
extension CarrierRepository: DependencyKey {
    public static var liveValue: CarrierRepository {
        let store = SwiftDataStore<Carrier, SDCarrier>()

        return CarrierRepository(
            fetchAll: {
                try await store.fetchAll(sortBy: [SortDescriptor(\.createdAt)])
            },
            add: { carrier in
                try await store.add(carrier)
            },
            update: { carrier in
                try await store.update(carrier)
            },
            delete: { id in
                try await store.delete(id: id)
            }
        )
    }
}
