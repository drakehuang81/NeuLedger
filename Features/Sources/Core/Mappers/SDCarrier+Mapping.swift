import Foundation
import SwiftData
import Domain

/// Bidirectional mapping between `SDCarrier` and `Carrier`.
extension SDCarrier: DomainConvertible {
    /// Converts this SwiftData model to a Domain `Carrier` value type.
    func toDomain() -> Carrier {
        Carrier(
            id: id,
            name: name,
            type: CarrierType(rawValue: typeRaw) ?? .phoneBarcodeCarrier,
            barcode: barcode,
            createdAt: createdAt
        )
    }

    /// Creates an `SDCarrier` from a Domain `Carrier`.
    ///
    /// - Parameters:
    ///   - domain: The Domain `Carrier` value to persist.
    ///   - context: The `ModelContext` in which to insert the new model.
    /// - Returns: A new `SDCarrier` instance inserted into the given context.
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
