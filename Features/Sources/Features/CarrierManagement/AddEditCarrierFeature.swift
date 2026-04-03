// Features/Sources/Features/CarrierManagement/AddEditCarrierFeature.swift
import ComposableArchitecture
import Domain
import Foundation

@Reducer
public struct AddEditCarrierFeature: Sendable {
    public init() {}

    public enum Mode: Equatable, Sendable {
        case add
        case edit(Carrier)
    }

    @ObservableState
    public struct State: Equatable {
        public var mode: Mode
        public var name: String
        public var type: CarrierType
        public var barcode: String
        public var barcodeError: String?
        public var isSaving: Bool = false
        public var saveError: String? = nil

        public init(mode: Mode = .add) {
            self.mode = mode
            switch mode {
            case .add:
                self.name = ""
                self.type = .phoneBarcodeCarrier
                self.barcode = ""
                self.barcodeError = nil
            case let .edit(carrier):
                self.name = carrier.name
                self.type = carrier.type
                self.barcode = carrier.barcode
                self.barcodeError = nil
            }
        }

        var canSave: Bool { barcodeError == nil && !barcode.isEmpty }
    }

    public enum Action: Sendable, Equatable {
        case nameChanged(String)
        case typeChanged(CarrierType)
        case barcodeChanged(String)
        case saveTapped
        case cancelTapped
        case savedSuccessfully
        case saveFailed(String)
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Sendable, Equatable {
            case saved
            case dismissed
        }
    }

    @Dependency(\.carrierClient) var carrierClient
    @Dependency(\.dismiss) var dismiss

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .nameChanged(name):
                state.name = name
                return .none

            case let .typeChanged(type):
                state.type = type
                state.barcodeError = Self.validate(barcode: state.barcode, type: type)
                return .none

            case let .barcodeChanged(barcode):
                state.barcode = barcode
                state.barcodeError = Self.validate(barcode: barcode, type: state.type)
                return .none

            case .saveTapped:
                guard state.canSave else { return .none }
                let trimmedName = state.name.trimmingCharacters(in: .whitespacesAndNewlines)
                let effectiveName = trimmedName.isEmpty
                    ? state.type.defaultName
                    : trimmedName
                let barcode = state.barcode
                let type = state.type
                let mode = state.mode
                state.isSaving = true

                return .run { send in
                    switch mode {
                    case .add:
                        let carrier = Carrier(name: effectiveName, type: type, barcode: barcode)
                        try await carrierClient.add(carrier)
                    case let .edit(existing):
                        let updated = Carrier(
                            id: existing.id,
                            name: effectiveName,
                            type: type,
                            barcode: barcode,
                            createdAt: existing.createdAt
                        )
                        try await carrierClient.update(updated)
                    }
                    await send(.savedSuccessfully)
                } catch: { error, send in
                    await send(.saveFailed(error.localizedDescription))
                }

            case .savedSuccessfully:
                state.isSaving = false
                state.saveError = nil
                return .run { send in
                    await send(.delegate(.saved))
                    await dismiss()
                }

            case let .saveFailed(message):
                state.isSaving = false
                state.saveError = message
                return .none

            case .cancelTapped:
                return .run { send in
                    await send(.delegate(.dismissed))
                    await dismiss()
                }

            case .delegate:
                return .none
            }
        }
    }

    private static func validate(barcode: String, type: CarrierType) -> String? {
        guard !barcode.isEmpty else { return nil }
        let pattern: String
        let errorKey: String
        switch type {
        case .phoneBarcodeCarrier:
            pattern = #"^/[A-Z0-9+.-]{7}$"#
            errorKey = "carrier_barcode_error_phone"
        case .citizenDigitalCertificate:
            pattern = #"^/P[A-Z0-9]{16}$"#
            errorKey = "carrier_barcode_error_cert"
        }
        let matches = barcode.range(of: pattern, options: .regularExpression) != nil
        return matches ? nil : String(localized: String.LocalizationValue(errorKey))
    }
}

extension CarrierType {
    var defaultName: String {
        switch self {
        case .phoneBarcodeCarrier: return String(localized: "carrier_type_phone_barcode")
        case .citizenDigitalCertificate: return String(localized: "carrier_type_citizen_cert")
        }
    }
}
