// NeuLedgerWidget/CarrierAppEntity.swift
import AppIntents
import Foundation

// MARK: - CarrierAppEntity

/// An `AppEntity` wrapper around a `CarrierEntry` so that
/// `CarrierSelectionIntent` can offer a system-native picker
/// in the widget's Edit sheet.
struct CarrierAppEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "carrier_entity_type_name")
    }

    static var defaultQuery = CarrierEntityQuery()

    let id: String
    let name: String
    let barcode: String

    var displayRepresentation: DisplayRepresentation {
        // Title: user-entered name (falls back to barcode when name is empty)
        // Subtitle: raw barcode string, for unique identification when multiple
        // carriers share the same name.
        let title = name.isEmpty ? barcode : name
        return DisplayRepresentation(
            title: "\(title)",
            subtitle: "\(barcode)"
        )
    }
}

// MARK: - CarrierEntityQuery

/// Provides `CarrierAppEntity` instances to the AppIntents framework so the
/// system can render the carrier picker and resolve previously-selected entities.
struct CarrierEntityQuery: EntityQuery {
    /// Resolve specific entities by ID (used when the system reads back the
    /// previously selected carrier on each widget render).
    func entities(for identifiers: [CarrierAppEntity.ID]) async throws -> [CarrierAppEntity] {
        let all = WidgetAppGroup.readAllCarriers()
        let lookup = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
        return identifiers.compactMap { id in
            guard let entry = lookup[id] else { return nil }
            return CarrierAppEntity(
                id: entry.id,
                name: entry.name,
                barcode: entry.barcode
            )
        }
    }

    /// Suggested entities shown in the picker.
    func suggestedEntities() async throws -> [CarrierAppEntity] {
        WidgetAppGroup.readAllCarriers().map { entry in
            CarrierAppEntity(
                id: entry.id,
                name: entry.name,
                barcode: entry.barcode
            )
        }
    }
}

// MARK: - CarrierSelectionIntent

/// The configurable intent that drives `CarrierWidget`.
/// User long-presses the widget → "Edit Widget" → picks a carrier.
struct CarrierSelectionIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "carrier_intent_title"
    static var description = IntentDescription("carrier_intent_description")

    @Parameter(title: "carrier_intent_parameter_title")
    var carrier: CarrierAppEntity?

    init() {}

    init(carrier: CarrierAppEntity?) {
        self.carrier = carrier
    }
}
