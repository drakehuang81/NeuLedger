/// NOTE: Suite name and keys MUST stay in sync with Shared/WidgetAppGroup.swift,
/// which is the Widget-side reader (outside Features SPM package).
import Foundation
import WidgetKit
import Dependencies
import Domain

extension WidgetSyncClient: DependencyKey {
    // MARK: - App Group constants
    //
    // Keep in sync with Shared/WidgetAppGroup.swift:
    //   static let suiteName = "group.com.drakehuang.NeuLedger"
    //   enum Key: String { case carrierBarcode, carrierType, carrierName, carrierUpdatedAt, carrierList }
    //
    // Widget kind keeps in sync with NeuLedgerWidget/CarrierWidget.swift:
    //   let kind: String = "CarrierWidget"

    private static let appGroupSuiteName = "group.com.drakehuang.NeuLedger"
    private static let keyBarcode        = "carrierBarcode"
    private static let keyType           = "carrierType"
    private static let keyName           = "carrierName"
    private static let keyUpdatedAt      = "carrierUpdatedAt"
    private static let keyList           = "carrierList"
    private static let widgetKind        = "CarrierWidget"

    public static let liveValue = Self(
        syncCarrier: { barcode, type, name in
            guard let defaults = UserDefaults(suiteName: appGroupSuiteName) else { return }
            defaults.set(barcode, forKey: keyBarcode)
            defaults.set(type,    forKey: keyType)
            defaults.set(name,    forKey: keyName)
            defaults.set(Date(),  forKey: keyUpdatedAt)
            await WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
        },
        clearCarrier: {
            guard let defaults = UserDefaults(suiteName: appGroupSuiteName) else { return }
            for key in [keyBarcode, keyType, keyName, keyUpdatedAt] {
                defaults.removeObject(forKey: key)
            }
            await WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
        },
        syncAllCarriers: { carriers in
            guard let defaults = UserDefaults(suiteName: appGroupSuiteName) else { return }
            // Mirror Shared/WidgetAppGroup.CarrierEntry — Core cannot import Shared/.
            struct CarrierEntryDTO: Codable {
                let id: String
                let barcode: String
                let typeRawValue: String
                let name: String
                let updatedAt: Date?
            }
            let dtos = carriers.map {
                CarrierEntryDTO(
                    id: $0.id.uuidString,
                    barcode: $0.barcode,
                    typeRawValue: $0.type.rawValue,
                    name: $0.name,
                    updatedAt: Date()
                )
            }
            guard let data = try? JSONEncoder().encode(dtos) else { return }
            defaults.set(data, forKey: keyList)
            await WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
        }
    )
}
