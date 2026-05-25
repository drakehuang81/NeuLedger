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
            ZStack {
                WarmGradientBackground(variant: .top)
                    .ignoresSafeArea()

                ScrollView {
                    // TODO: design includes Opening Balance, "Set as Primary"
                    // toggle, and an AI suggestion footer. None are wired:
                    // AddEditAccountFeature.State has no openingBalance /
                    // isPrimary, and the Account domain model has no isPrimary
                    // flag. Extend reducer + entity before adding sections.
                    VStack(spacing: 22) {
                        typeSection
                        nameSection
                        iconSection
                        colorSection
                        previewSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 60)
                }
            }
            .navigationTitle(isEditMode
                ? String(localized: "account_form_edit_title")
                : String(localized: "account_form_add_title")
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
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

    // MARK: - Type Section

    private var typeSection: some View {
        sectionGroup(label: "common_type") {
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                spacing: 10
            ) {
                ForEach(AccountType.allCases, id: \.self) { type in
                    typeTile(type)
                }
            }
        }
    }

    private func typeTile(_ type: AccountType) -> some View {
        let isSelected = store.type == type
        let color = Color.Design.fromHex(type.defaultColor)
        return Button {
            store.send(.typeChanged(type))
            store.send(.iconChanged(type.defaultIcon))
            store.send(.colorHexChanged(type.defaultColor))
        } label: {
            VStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(color)
                    .frame(width: 36, height: 36)
                    .overlay {
                        Image(systemName: type.defaultIcon)
                            .font(Font.Design.size18Semibold)
                            .foregroundStyle(.white)
                    }
                Text(type.displayLabel)
                    .font(Font.Design.size12Semibold)
                    .foregroundStyle(Color.Design.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.Design.surface.opacity(isSelected ? 0.9 : 0.5))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        isSelected ? color : Color.Design.separator,
                        lineWidth: isSelected ? 1.5 : 0.5
                    )
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Name Section

    private var nameSection: some View {
        sectionGroup(label: "common_name") {
            VStack(alignment: .leading, spacing: 6) {
                GlassContainer(cornerRadius: 12, padding: 14) {
                    TextField(
                        String(localized: "account_form_name_placeholder"),
                        text: Binding(
                            get: { store.name },
                            set: { store.send(.nameChanged($0)) }
                        )
                    )
                    .font(Font.Design.body)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                }
                if let error = store.nameError {
                    ErrorText(error)
                        .padding(.horizontal, 4)
                }
            }
        }
    }

    // MARK: - Icon Section

    private var iconSection: some View {
        sectionGroup(label: "common_icon") {
            GlassContainer(cornerRadius: 14, padding: 12) {
                IconPickerRow(
                    icons: DesignConstants.accountIconOptions,
                    selectedIcon: store.icon,
                    accentColor: Color.Design.fromHex(store.colorHex),
                    onSelect: { store.send(.iconChanged($0)) }
                )
            }
        }
    }

    // MARK: - Color Section

    private var colorSection: some View {
        sectionGroup(label: "common_color") {
            GlassContainer(cornerRadius: 14, padding: 14) {
                ColorSwatchPicker(
                    colors: DesignConstants.accountColorOptions,
                    selectedHex: store.colorHex,
                    onSelect: { store.send(.colorHexChanged($0)) }
                )
            }
        }
    }

    // MARK: - Preview Section

    private var previewSection: some View {
        sectionGroup(label: "common_preview") {
            GlassContainer(cornerRadius: 14, padding: 14) {
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.Design.fromHex(store.colorHex))
                        .frame(width: 44, height: 44)
                        .overlay {
                            Image(systemName: store.icon)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                    Text(store.name.isEmpty
                        ? String(localized: "account_form_name_placeholder")
                        : store.name
                    )
                    .font(Font.Design.body.weight(.semibold))
                    .foregroundStyle(
                        store.name.isEmpty
                            ? Color.Design.textTertiary
                            : Color.Design.textPrimary
                    )
                    Spacer()
                }
            }
        }
    }

    // MARK: - Section Group helper

    @ViewBuilder
    private func sectionGroup<Content: View>(
        label: LocalizedStringKey,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(Font.Design.size11Medium)
                .textCase(.uppercase)
                .tracking(1.2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
            content()
        }
    }
}

#Preview("Add") {
    AddEditAccountView(
        store: Store(initialState: AddEditAccountFeature.State(mode: .add)) {
            AddEditAccountFeature()
        }
    )
}

#Preview("Edit") {
    AddEditAccountView(
        store: Store(initialState: AddEditAccountFeature.State(
            mode: .edit(Account(
                name: "永豐銀行",
                type: .bank,
                icon: "building.columns",
                color: "#0A84FF"
            ))
        )) {
            AddEditAccountFeature()
        }
    )
}
