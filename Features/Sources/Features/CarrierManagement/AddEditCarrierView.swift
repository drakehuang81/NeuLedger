// Features/Sources/Features/CarrierManagement/AddEditCarrierView.swift
import Common
import ComposableArchitecture
import Domain
import SwiftUI

public struct AddEditCarrierView: View {
    @Bindable var store: StoreOf<AddEditCarrierFeature>

    public init(store: StoreOf<AddEditCarrierFeature>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            Form {
                // MARK: Name
                Section {
                    TextField(
                        String(localized: "carrier_name_placeholder"),
                        text: Binding(
                            get: { store.name },
                            set: { store.send(.nameChanged($0)) }
                        )
                    )
                } header: {
                    Text(String(localized: "carrier_name_label"))
                }

                // MARK: Type
                Section {
                    Picker(
                        String(localized: "carrier_type_label"),
                        selection: Binding(
                            get: { store.type },
                            set: { store.send(.typeChanged($0)) }
                        )
                    ) {
                        ForEach(CarrierType.allCases, id: \.self) { type in
                            Text(type.defaultName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(.init(top: 8, leading: 0, bottom: 8, trailing: 0))
                }

                // MARK: Barcode
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        TextField(
                            store.type == .phoneBarcodeCarrier ? "/XXXXXXX" : "/PXXXXXXXXXXXXXXXX",
                            text: Binding(
                                get: { store.barcode },
                                set: { store.send(.barcodeChanged($0.uppercased())) }
                            )
                        )
                        .font(.system(.body, design: .monospaced))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)

                        if let error = store.barcodeError {
                            Text(error)
                                .font(Font.Design.caption)
                                .foregroundStyle(Color.Design.expenseRed)
                        }
                    }
                } header: {
                    Text(String(localized: "carrier_barcode_label"))
                }

                // MARK: Save Error
                if let saveError = store.saveError {
                    Section {
                        Text(saveError)
                            .font(Font.Design.caption)
                            .foregroundStyle(Color.Design.expenseRed)
                    }
                }
            }
            .navigationTitle(
                store.mode == .add
                    ? String(localized: "carrier_add_title")
                    : String(localized: "carrier_edit_title")
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(String(localized: "common_cancel")) {
                        store.send(.cancelTapped)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "common_save")) {
                        store.send(.saveTapped)
                    }
                    .fontWeight(.semibold)
                    .disabled(!store.canSave || store.isSaving)
                }
            }
        }
    }
}
