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
            ZStack {
                WarmGradientBackground(variant: .top)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 22) {
                        livePreviewHero
                        typeSection
                        nameSection
                        iconSection
                        colorSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 60)
                }
            }
            .navigationTitle(isEditMode
                ? String(localized: "category_form_edit_title")
                : String(localized: "category_form_add_title")
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

    // MARK: - Live Preview Hero

    private var livePreviewHero: some View {
        let color = Color.Design.fromHex(store.colorHex)
        return VStack(spacing: 10) {
            Circle()
                .fill(color)
                .frame(width: 80, height: 80)
                .overlay {
                    Image(systemName: store.icon)
                        .font(Font.Design.size32Semibold)
                        .foregroundStyle(.white)
                }
                .shadow(color: color.opacity(0.35), radius: 12, x: 0, y: 8)

            Text(store.name.isEmpty
                ? String(localized: "category_form_name_placeholder")
                : store.name
            )
            .font(Font.Design.size20Semibold)
            .foregroundStyle(
                store.name.isEmpty
                    ? Color.Design.textTertiary
                    : Color.Design.textPrimary
            )

            Text(typeEyebrow)
                .font(Font.Design.size10Medium.monospacedDigit())
                .textCase(.uppercase)
                .tracking(1.2)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
        .frame(maxWidth: .infinity)
    }

    private var typeEyebrow: String {
        switch store.type {
        case .expense: return String(localized: "common_expense")
        case .income:  return String(localized: "common_income")
        case .transfer: return ""
        }
    }

    // MARK: - Type Section

    private var typeSection: some View {
        sectionGroup(label: "common_type") {
            HStack(spacing: 0) {
                typePill(.expense, label: "common_expense", activeColor: Color.Design.expenseRed)
                typePill(.income, label: "common_income", activeColor: Color.Design.incomeGreen)
            }
            .padding(3)
            .background {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.Design.textPrimary.opacity(0.06))
            }
            .opacity(store.isDefault ? 0.5 : 1)
            .disabled(store.isDefault)
        }
    }

    private func typePill(
        _ type: TransactionType,
        label: LocalizedStringKey,
        activeColor: Color
    ) -> some View {
        let isActive = store.type == type
        return Button {
            store.send(.typeChanged(type))
        } label: {
            Text(label)
                .font(Font.Design.size13Semibold)
                .foregroundStyle(
                    isActive ? activeColor : Color.Design.textSecondary
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background {
                    if isActive {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Color.Design.surface)
                            .shadow(color: .black.opacity(0.08), radius: 3, y: 1)
                    }
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
                        String(localized: "category_form_name_placeholder"),
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
                    icons: DesignConstants.categoryIconOptions,
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
                    colors: DesignConstants.categoryColorOptions,
                    selectedHex: store.colorHex,
                    onSelect: { store.send(.colorHexChanged($0)) }
                )
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

#Preview("Add — Expense") {
    AddEditCategoryView(
        store: Store(initialState: AddEditCategoryFeature.State(mode: .add(.expense))) {
            AddEditCategoryFeature()
        }
    )
}

#Preview("Edit — Default") {
    AddEditCategoryView(
        store: Store(initialState: AddEditCategoryFeature.State(
            mode: .edit(Domain.Category(
                name: "餐飲",
                icon: "fork.knife",
                color: "#E8835A",
                type: .expense,
                sortOrder: 0,
                isDefault: true
            ))
        )) {
            AddEditCategoryFeature()
        }
    )
}
