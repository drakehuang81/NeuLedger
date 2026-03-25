import Common
import ComposableArchitecture
import Domain
import SwiftUI

public struct AddEditCategoryView: View {
    @Bindable var store: StoreOf<AddEditCategoryFeature>

    public init(store: StoreOf<AddEditCategoryFeature>) {
        self.store = store
    }

    private var isEditMode: Bool {
        if case .edit = store.mode { return true }
        return false
    }

    public var body: some View {
        NavigationStack {
            Form {
                // MARK: 名稱
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        TextField(
                            String(localized: "category_form_name_placeholder"),
                            text: Binding(
                                get: { store.name },
                                set: { store.send(.nameChanged($0)) }
                            )
                        )
                        if let error = store.nameError {
                            Text(error)
                                .font(Font.Design.caption)
                                .foregroundStyle(Color.Design.expenseRed)
                        }
                    }
                } header: {
                    Text("common_name")
                }

                // MARK: 類型
                Section {
                    Picker(
                        String(localized: "common_type"),
                        selection: Binding(
                            get: { store.type },
                            set: { store.send(.typeChanged($0)) }
                        )
                    ) {
                        Text("common_expense").tag(TransactionType.expense)
                        Text("common_income").tag(TransactionType.income)
                    }
                    .pickerStyle(.segmented)
                    .disabled(store.isDefault)
                    .listRowInsets(.init(top: 12, leading: 16, bottom: 12, trailing: 16))
                } header: {
                    Text("common_type")
                }

                // MARK: 圖示
                Section {
                    IconPickerRow(
                        icons: DesignConstants.categoryIconOptions,
                        selectedIcon: store.icon,
                        accentColor: Color(hex: store.colorHex),
                        onSelect: { store.send(.iconChanged($0)) }
                    )
                    .listRowInsets(.init(top: 0, leading: 12, bottom: 0, trailing: 12))
                } header: {
                    Text("common_icon")
                }

                // MARK: 顏色
                Section {
                    ColorSwatchPicker(
                        colors: DesignConstants.categoryColorOptions,
                        selectedHex: store.colorHex,
                        onSelect: { store.send(.colorHexChanged($0)) }
                    )
                    .listRowInsets(.init(top: 0, leading: 12, bottom: 0, trailing: 12))
                } header: {
                    Text("common_color")
                }

                // MARK: Preview
                Section {
                    HStack(spacing: 12) {
                        IconBadge(systemImage: store.icon, color: Color(hex: store.colorHex))
                        Text(store.name.isEmpty ? String(localized: "category_form_name_placeholder") : store.name)
                            .font(Font.Design.body)
                            .fontWeight(.semibold)
                            .foregroundStyle(
                                store.name.isEmpty
                                    ? Color.Design.textTertiary
                                    : Color.Design.textPrimary
                            )
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("common_preview")
                }
            }
            .navigationTitle(isEditMode ? String(localized: "category_form_edit_title") : String(localized: "category_form_add_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common_cancel")) {
                        store.send(.cancelTapped)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common_save")) {
                        store.send(.saveTapped)
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

}
