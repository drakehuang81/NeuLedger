import Foundation
import SwiftData

/// SwiftData persistence model for a user's government e-invoice carrier.
@Model
final class SDCarrier {
    /// The unique identifier of the carrier.
    var id: UUID = UUID()

    /// The display name of the carrier.
    var name: String = ""

    /// The raw String value of the `CarrierType` enum associated with this carrier.
    var typeRaw: String = ""

    /// The barcode string used to identify this carrier.
    var barcode: String = ""

    /// The date and time this carrier record was created.
    var createdAt: Date = Date()

    init(
        id: UUID = UUID(),
        name: String,
        typeRaw: String,
        barcode: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.typeRaw = typeRaw
        self.barcode = barcode
        self.createdAt = createdAt
    }
}
