// Shared/WidgetAppGroup.swift
import Foundation

/// Shared App Group helper for reading and writing widget configuration
/// between the main app and the Widget Extension.
///
/// The main app is the sole writer; the Widget Extension is read-only.
enum WidgetAppGroup {
    static let suiteName = "group.com.drake.NeuLedger"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }

    // MARK: - Keys

    private enum Key: String {
        // Legacy single-carrier keys (kept for backward compat during transition)
        case carrierBarcode
        case carrierType
        case carrierName
        case carrierUpdatedAt
        // New list key (JSON-encoded [CarrierEntry])
        case carrierList
    }

    // MARK: - Legacy single-carrier read (kept for compat)

    /// Reads the legacy single carrier configuration from App Group.
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
        // Legacy entry has no ID — use a deterministic placeholder so callers can
        // still identify it; new code should prefer readAllCarriers().
        return CarrierEntry(
            id: "legacy",
            barcode: barcode,
            typeRawValue: typeRaw,
            name: name,
            updatedAt: updatedAt
        )
    }

    // MARK: - Legacy single-carrier write (main app only)

    /// Writes legacy single carrier configuration to App Group.
    static func writeCarrier(barcode: String, type: String, name: String) {
        guard let defaults else { return }
        defaults.set(barcode, forKey: Key.carrierBarcode.rawValue)
        defaults.set(type, forKey: Key.carrierType.rawValue)
        defaults.set(name, forKey: Key.carrierName.rawValue)
        defaults.set(Date(), forKey: Key.carrierUpdatedAt.rawValue)
    }

    /// Clears legacy single carrier data from App Group.
    static func clearCarrier() {
        guard let defaults else { return }
        for key in [Key.carrierBarcode, .carrierType, .carrierName, .carrierUpdatedAt] {
            defaults.removeObject(forKey: key.rawValue)
        }
    }

    // MARK: - Full carrier list I/O (new)

    /// Reads all carriers from the App Group. Returns an empty array on missing/corrupt data.
    static func readAllCarriers() -> [CarrierEntry] {
        guard let defaults,
              let data = defaults.data(forKey: Key.carrierList.rawValue) else {
            return []
        }
        return (try? JSONDecoder().decode([CarrierEntry].self, from: data)) ?? []
    }

    /// Writes all carriers to the App Group. Main app only.
    static func writeAllCarriers(_ carriers: [CarrierEntry]) {
        guard let defaults else { return }
        guard let data = try? JSONEncoder().encode(carriers) else { return }
        defaults.set(data, forKey: Key.carrierList.rawValue)
    }
}

// MARK: - CarrierEntry

/// A lightweight value type representing carrier data read from App Group.
/// Used by the Widget Extension — no dependency on Domain layer.
struct CarrierEntry: Codable, Hashable {
    let id: String              // UUID string (or "legacy" for migration entries)
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
