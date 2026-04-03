import Foundation
import SwiftData

/// SwiftData persistence model for a user's government e-invoice carrier.
@Model
final class SDCarrier {
    var id: UUID = UUID()
    var name: String = ""
    var typeRaw: String = ""
    var barcode: String = ""
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
