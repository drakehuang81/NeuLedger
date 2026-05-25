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
                        previewHero
                        typeSection
                        basicInfoSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 60)
                }
            }
            .navigationTitle(
                isEditMode
                    ? String(localized: "carrier_edit_title")
                    : String(localized: "carrier_add_title")
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
                    .disabled(!store.canSave || store.isSaving)
                }
            }
        }
    }

    // MARK: - Preview Hero

    private var previewHero: some View {
        VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(typeColor(store.type))
                    .frame(width: 80, height: 80)
                    .shadow(color: typeColor(store.type).opacity(0.35), radius: 12, x: 0, y: 8)
                Image(systemName: typeIcon(store.type))
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(.white)
                    .symbolRenderingMode(.hierarchical)
            }

            Text(
                store.name.isEmpty
                    ? store.type.defaultName
                    : store.name
            )
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(
                store.name.isEmpty
                    ? Color.Design.textTertiary
                    : Color.Design.textPrimary
            )

            if !store.barcode.isEmpty {
                Text(store.barcode)
                    .font(.system(size: 12, design: .monospaced).monospacedDigit())
                    .foregroundStyle(Color.Design.textSecondary)
                    .tracking(0.5)
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Type Section

    private var typeSection: some View {
        sectionGroup(label: "carrier_form_type_label") {
            HStack(spacing: 8) {
                typeCard(.phoneBarcodeCarrier)
                typeCard(.citizenDigitalCertificate)
            }
        }
    }

    private func typeCard(_ type: CarrierType) -> some View {
        let isSelected = store.type == type
        let accent = typeColor(type)
        return Button {
            store.send(.typeChanged(type))
        } label: {
            GlassContainer(cornerRadius: 16, padding: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(accent)
                            .frame(width: 32, height: 32)
                        Image(systemName: typeIcon(type))
                            .font(Font.Design.size15Semibold)
                            .foregroundStyle(.white)
                            .symbolRenderingMode(.hierarchical)
                    }
                    Text(type.defaultName)
                        .font(Font.Design.size13Semibold)
                        .foregroundStyle(Color.Design.textPrimary)

                    Text(typeBarcodeFormat(type))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color.Design.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .topTrailing) {
                    if isSelected {
                        ZStack {
                            Circle()
                                .fill(accent)
                                .frame(width: 18, height: 18)
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        isSelected ? accent : Color.clear,
                        lineWidth: 1.5
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Basic Info Section

    private var basicInfoSection: some View {
        sectionGroup(label: "carrier_form_basic_label") {
            VStack(alignment: .leading, spacing: 8) {
                GlassContainer(cornerRadius: 16, padding: 0) {
                    VStack(spacing: 0) {
                        // Name field
                        HStack {
                            Text(String(localized: "carrier_name_label"))
                                .font(Font.Design.body.weight(.medium))
                                .foregroundStyle(Color.Design.textPrimary)
                                .frame(width: 60, alignment: .leading)
                            TextField(
                                String(localized: "carrier_name_placeholder"),
                                text: Binding(
                                    get: { store.name },
                                    set: { store.send(.nameChanged($0)) }
                                )
                            )
                            .font(Font.Design.body)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(Color.Design.textPrimary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 13)

                        Divider()
                            .padding(.horizontal, 16)

                        // Barcode field
                        HStack {
                            Text(String(localized: "carrier_barcode_label"))
                                .font(Font.Design.body.weight(.medium))
                                .foregroundStyle(Color.Design.textPrimary)
                                .frame(width: 60, alignment: .leading)
                            TextField(
                                typeBarcodeFormat(store.type),
                                text: Binding(
                                    get: { store.barcode },
                                    set: { store.send(.barcodeChanged($0.uppercased())) }
                                )
                            )
                            .font(.system(.body, design: .monospaced))
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(
                                store.barcodeError != nil
                                    ? Color.Design.expenseRed
                                    : Color.Design.textPrimary
                            )
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.characters)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 13)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            store.barcodeError != nil
                                ? Color.Design.expenseRed.opacity(0.4)
                                : Color.clear,
                            lineWidth: 1
                        )
                )

                // Barcode error
                if let error = store.barcodeError {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(Font.Design.size11)
                            .foregroundStyle(Color.Design.expenseRed)
                        Text(error)
                            .font(Font.Design.size11)
                            .foregroundStyle(Color.Design.expenseRed)
                            .lineSpacing(2)
                    }
                    .padding(.horizontal, 6)
                } else {
                    // Format hint
                    Text(barcodeFormatHint(store.type))
                        .font(Font.Design.size11)
                        .foregroundStyle(Color.Design.textSecondary)
                        .lineSpacing(2)
                        .padding(.horizontal, 6)
                }

                // Save error
                if let saveError = store.saveError {
                    ErrorText(saveError)
                        .padding(.horizontal, 4)
                }
            }
        }
    }

    // MARK: - Section Group Helper

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

    // MARK: - Type Helpers

    private func typeIcon(_ type: CarrierType) -> String {
        switch type {
        case .phoneBarcodeCarrier: return "iphone"
        case .citizenDigitalCertificate: return "creditcard"
        }
    }

    private func typeColor(_ type: CarrierType) -> Color {
        switch type {
        case .phoneBarcodeCarrier: return Color.Design.accentOrange
        case .citizenDigitalCertificate: return Color(red: 0.37, green: 0.36, blue: 0.90)
        }
    }

    private func typeBarcodeFormat(_ type: CarrierType) -> String {
        switch type {
        case .phoneBarcodeCarrier: return "/XXXXXXX"
        case .citizenDigitalCertificate: return "/PXXXXXXXXXXXXXXXX"
        }
    }

    private func barcodeFormatHint(_ type: CarrierType) -> String {
        switch type {
        case .phoneBarcodeCarrier:
            return String(localized: "carrier_form_barcode_hint_phone")
        case .citizenDigitalCertificate:
            return String(localized: "carrier_form_barcode_hint_cert")
        }
    }
}

#Preview("Add") {
    AddEditCarrierView(
        store: Store(initialState: AddEditCarrierFeature.State(mode: .add)) {
            AddEditCarrierFeature()
        }
    )
}
