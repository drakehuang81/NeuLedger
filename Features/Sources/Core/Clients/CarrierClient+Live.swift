import Foundation
import SwiftData
import Domain
import Dependencies

extension CarrierClient: DependencyKey {
    public static var liveValue: CarrierClient {
        @Dependency(\.databaseClient) var databaseClient

        return CarrierClient(
            fetchAll: {
                try databaseClient.fetch(
                    FetchDescriptor<SDCarrier>(sortBy: [SortDescriptor(\.createdAt)])
                )
            },
            add: { carrier in
                try databaseClient.add(carrier, as: SDCarrier.self)
            },
            update: { carrier in
                let carrierId = carrier.id
                try databaseClient.update(
                    matching: FetchDescriptor<SDCarrier>(
                        predicate: #Predicate { $0.id == carrierId }
                    )
                ) { existing, _ in
                    existing.name = carrier.name
                    existing.typeRaw = carrier.type.rawValue
                    existing.barcode = carrier.barcode
                }
            },
            delete: { id in
                try databaseClient.deleteFirst(
                    matching: FetchDescriptor<SDCarrier>(
                        predicate: #Predicate { $0.id == id }
                    )
                )
            }
        )
    }
}
