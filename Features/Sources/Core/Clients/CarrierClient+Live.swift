import Foundation
import SwiftData
import Domain
import Dependencies

/// Live implementation of `CarrierClient` backed by `SwiftDataStore`.
extension CarrierClient: DependencyKey {
    public static var liveValue: CarrierClient {
        let store = SwiftDataStore<Carrier, SDCarrier>()

        return CarrierClient(
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
