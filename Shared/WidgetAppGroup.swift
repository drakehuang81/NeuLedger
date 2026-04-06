// Shared/WidgetAppGroup.swift
import Foundation

/// Shared App Group helper for reading and writing widget configuration
/// between the main app and the Widget Extension.
///
/// The main app is the sole writer; the Widget Extension is read-only.
enum WidgetAppGroup {
    static let suiteName = "group.com.drakehuang.NeuLedger"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }

    // MARK: - Keys

    private enum Key: String {
        case carrierBarcode
        case carrierType
        case carrierName
        case carrierUpdatedAt
    }

    // MARK: - Carrier Read

    /// Reads the current carrier configuration from App Group.
    /// Returns `nil` if no carrier is configured or data is inconsistent.
    static func readCarrier() -> CarrierEntry? {
        guard let defaults,
              let barcode = defaults.string(forKey: Key.carrierBarcode.rawValue),
              !barcode.isEmpty,
              let typeRaw = defaults.string(forKey: Key.carrierType.rawValue),
              !typeRaw.isEmpty else {
            return nil
        }
        let name = defaults.string(forKey: Key.carrierName.rawValue) ?? ""
        let updatedAt = defaults.object(forKey: Key.carrierUpdatedAt.rawValue) as? Date
        return CarrierEntry(barcode: barcode, typeRawValue: typeRaw, name: name, updatedAt: updatedAt)
    }

    // MARK: - Carrier Write (main app only)

    /// Writes carrier configuration to App Group.
    static func writeCarrier(barcode: String, type: String, name: String) {
        guard let defaults else { return }
        defaults.set(barcode, forKey: Key.carrierBarcode.rawValue)
        defaults.set(type, forKey: Key.carrierType.rawValue)
        defaults.set(name, forKey: Key.carrierName.rawValue)
        defaults.set(Date(), forKey: Key.carrierUpdatedAt.rawValue)
    }

    /// Clears all carrier data from App Group (e.g. when the active widget carrier is deleted).
    static func clearCarrier() {
        guard let defaults else { return }
        for key in [Key.carrierBarcode, .carrierType, .carrierName, .carrierUpdatedAt] {
            defaults.removeObject(forKey: key.rawValue)
        }
    }
}

// MARK: - CarrierEntry

/// A lightweight value type representing carrier data read from App Group.
/// Used by the Widget Extension — no dependency on Domain layer.
struct CarrierEntry {
    let barcode: String
    let typeRawValue: String    // "phoneBarcodeCarrier" or "citizenDigitalCertificate"
    let name: String
    let updatedAt: Date?

    var typeDisplayName: String {
        switch typeRawValue {
        case "phoneBarcodeCarrier":
            return String(localized: "carrier_type_phone_barcode")
        case "citizenDigitalCertificate":
            return String(localized: "carrier_type_citizen_cert")
        default:
            return typeRawValue
        }
    }
}
