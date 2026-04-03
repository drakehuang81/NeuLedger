import Foundation
import SwiftData
import Domain

extension SDCarrier: DomainConvertible {
    func toDomain() -> Carrier {
        Carrier(
            id: id,
            name: name,
            type: CarrierType(rawValue: typeRaw) ?? .phoneBarcodeCarrier,
            barcode: barcode,
            createdAt: createdAt
        )
    }

    @discardableResult
    static func from(_ domain: Carrier, context: ModelContext) -> SDCarrier {
        let model = SDCarrier(
            id: domain.id,
            name: domain.name,
            typeRaw: domain.type.rawValue,
            barcode: domain.barcode,
            createdAt: domain.createdAt
        )
        context.insert(model)
        return model
    }
}
