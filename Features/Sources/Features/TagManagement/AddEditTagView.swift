import Common
import ComposableArchitecture
import Domain
import SwiftUI

public struct AddEditTagView: View {
    @Bindable var store: StoreOf<AddEditTagFeature>

    public init(store: StoreOf<AddEditTagFeature>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            Form {
                // MARK: Name Field
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        TextField(String(localized: "tag_form_name_placeholder"), text: Binding(
                            get: { store.name },
                            set: { store.send(.nameChanged($0)) }
                        ))

                        if let error = store.nameError {
                            Text(error)
                                .font(Font.Design.caption)
                                .foregroundStyle(Color.Design.expenseRed)
                        }
                    }
                } header: {
                    Text("common_name")
                }

                // MARK: Color Picker
                Section {
                    ColorSwatchPicker(
                        colors: DesignConstants.tagColorOptions,
                        selectedHex: store.colorHex,
                        layout: .grid(columns: 6),
                        onSelect: { store.send(.colorHexChanged($0)) }
                    )
                    .listRowInsets(.init(top: 0, leading: 12, bottom: 0, trailing: 12))
                } header: {
                    Text("common_color")
                }
            }
            .navigationTitle(store.navigationTitle)
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
                }
            }
        }
    }

}
