import Foundation

/// A Taiwan government e-invoice carrier stored by the user for quick reference.
public struct Carrier: Identifiable, Equatable, Hashable, Codable, Sendable {
    public let id: UUID
    public var name: String
    public var type: CarrierType
    public var barcode: String
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        type: CarrierType,
        barcode: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.barcode = barcode
        self.createdAt = createdAt
    }
}

public enum CarrierType: String, Codable, CaseIterable, Sendable {
    case phoneBarcodeCarrier
    case citizenDigitalCertificate
}
