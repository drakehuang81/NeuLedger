import Foundation

/// A Taiwan government e-invoice carrier stored by the user for quick reference.
///
/// Use `Carrier` to record the user's personal e-invoice carrier identifiers so they can be
/// quickly selected when logging a transaction that should be linked to a government carrier.
public struct Carrier: Identifiable, Equatable, Hashable, Codable, Sendable {
    /// The unique identifier of the carrier.
    public let id: UUID

    /// The user-defined display name of the carrier, such as "我的手機載具" or "自然人憑證".
    public var name: String

    /// The kind of carrier, determining how its barcode is formatted and used.
    public var type: CarrierType

    /// The carrier barcode string used to claim e-invoices.
    ///
    /// For ``CarrierType/phoneBarcodeCarrier`` this is an 8-character code beginning with
    /// a forward slash, e.g. `/ABC1234`. For ``CarrierType/citizenDigitalCertificate`` this
    /// is the 16-character certificate serial number.
    public var barcode: String

    /// The date and time when this carrier record was created.
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
