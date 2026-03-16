import Common
import ComposableArchitecture
import Domain
import SwiftUI

public struct AddEditAccountView: View {
    @Bindable var store: StoreOf<AddEditAccountFeature>

    private static let predefinedIcons: [String] = [
        "creditcard", "banknote", "wallet.bifold", "building.columns",
        "dollarsign.circle", "star.circle", "cart.circle", "briefcase.circle"
    ]

    private static let predefinedColors: [String] = [
        "#3478F6", "#34C759", "#FF9500", "#FF3B30", "#5856D6",
        "#FF2D55", "#AF52DE", "#00C7BE", "#32ADE6", "#FF9F0A"
    ]

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
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(Self.predefinedIcons, id: \.self) { iconName in
                                Button {
                                    store.send(.iconChanged(iconName))
                                } label: {
                                    ZStack {
                                        Circle()
                                            .fill(store.icon == iconName
                                                  ? Color(hex: store.colorHex).opacity(0.2)
                                                  : Color.Design.surfaceSecondary)
                                            .frame(width: 48, height: 48)
                                            .overlay(
                                                Circle()
                                                    .stroke(
                                                        store.icon == iconName
                                                            ? Color(hex: store.colorHex)
                                                            : Color.clear,
                                                        lineWidth: 2
                                                    )
                                            )
                                        Image(systemName: iconName)
                                            .symbolRenderingMode(.hierarchical)
                                            .foregroundStyle(
                                                store.icon == iconName
                                                    ? Color(hex: store.colorHex)
                                                    : Color.Design.textSecondary
                                            )
                                            .font(.system(size: 20))
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                } header: {
                    Text("common_icon")
                }

                // MARK: 顏色
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(Self.predefinedColors, id: \.self) { hex in
                                Button {
                                    store.send(.colorHexChanged(hex))
                                } label: {
                                    ZStack {
                                        Circle()
                                            .fill(Color(hex: hex))
                                            .frame(width: 36, height: 36)
                                        if store.colorHex == hex {
                                            Circle()
                                                .stroke(Color.Design.textPrimary, lineWidth: 2)
                                                .frame(width: 36, height: 36)
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundStyle(Color.Design.textInverse)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 8)
                    }
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
