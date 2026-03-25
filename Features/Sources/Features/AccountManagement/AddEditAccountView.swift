import Common
import ComposableArchitecture
import Domain
import SwiftUI

public struct AddEditAccountView: View {
    @Bindable var store: StoreOf<AddEditAccountFeature>

    public init(store: StoreOf<AddEditAccountFeature>) {
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
                    TextField(String(localized: "account_form_name_placeholder"), text: Binding(
                        get: { store.name },
                        set: { store.send(.nameChanged($0)) }
                    ))
                    if let error = store.nameError {
                        Text(error)
                            .font(Font.Design.caption)
                            .foregroundStyle(Color.Design.expenseRed)
                    }
                } header: {
                    Text("common_name")
                }

                // MARK: 帳戶類型
                Section {
                    Picker(String(localized: "common_type"), selection: Binding(
                        get: { store.type },
                        set: { store.send(.typeChanged($0)) }
                    )) {
                        ForEach(AccountType.allCases, id: \.self) { type in
                            Text(type.displayLabel).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                } header: {
                    Text("common_type")
                }

                // MARK: 圖示
                Section {
                    IconPickerRow(
                        icons: DesignConstants.accountIconOptions,
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
                        colors: DesignConstants.accountColorOptions,
                        selectedHex: store.colorHex,
                        onSelect: { store.send(.colorHexChanged($0)) }
                    )
                    .listRowInsets(.init(top: 0, leading: 12, bottom: 0, trailing: 12))
                } header: {
                    Text("common_color")
                }

                // MARK: 預覽
                Section {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: store.colorHex).opacity(0.15))
                                .frame(width: 44, height: 44)
                            Image(systemName: store.icon)
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(Color(hex: store.colorHex))
                                .font(.system(size: 20))
                        }
                        Text(store.name.isEmpty ? String(localized: "account_form_name_placeholder") : store.name)
                            .font(Font.Design.body)
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
            .navigationTitle(isEditMode ? String(localized: "account_form_edit_title") : String(localized: "account_form_add_title"))
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
