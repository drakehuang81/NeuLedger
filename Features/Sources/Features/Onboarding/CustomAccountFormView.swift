import SwiftUI
import ComposableArchitecture
import Common
import Domain

struct CustomAccountFormView: View {
    @Bindable var store: StoreOf<CustomAccountFormFeature>

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Capsule()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 38, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
                .padding(.bottom, 18)

            Text("onboarding_custom_sheet_title")
                .font(.system(size: 24, weight: .bold))
                .padding(.bottom, 4)
            Text("onboarding_custom_sheet_subtitle")
                .font(Font.Design.size13)
                .foregroundStyle(.secondary)
                .padding(.bottom, 18)

            FieldLabel("onboarding_custom_name_label")
            GlassContainer(cornerRadius: 14, padding: 12) {
                TextField("onboarding_custom_name_placeholder", text: $store.name)
                    .font(Font.Design.size16)
            }
            .padding(.bottom, 14)

            FieldLabel("onboarding_custom_type_label")
            HStack(spacing: 8) {
                ForEach(AccountType.allCases, id: \.self) { type in
                    typeChip(for: type)
                }
            }
            .padding(.bottom, 14)

            FieldLabel("onboarding_custom_color_label")
            ColorSwatchPicker(
                colors: CustomAccountFormFeature.colorPalette,
                selectedHex: store.color,
                onSelect: { store.color = $0 }
            )
            .padding(.bottom, 18)

            PrimaryButton("onboarding_custom_submit") {
                store.send(.submitTapped)
            }
            .opacity(store.canSubmit ? 1 : 0.5)
            .disabled(!store.canSubmit)
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 28)
    }

    @ViewBuilder
    private func typeChip(for type: AccountType) -> some View {
        let isSelected = store.type == type
        Button {
            store.type = type
        } label: {
            VStack(spacing: 4) {
                Image(systemName: type.defaultIcon)
                    .font(.system(size: 18))
                    .foregroundStyle(isSelected ? Color.Design.brandPrimary : Color.primary)
                Text(type.displayLabel)
                    .font(Font.Design.size11)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.secondary.opacity(0.06))
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            isSelected ? Color.Design.brandPrimary : Color.clear,
                            lineWidth: 2
                        )
                }
            }
        }
        .buttonStyle(.plain)
    }
}

private struct FieldLabel: View {
    let key: LocalizedStringKey
    init(_ key: LocalizedStringKey) { self.key = key }
    var body: some View {
        Text(key)
            .font(Font.Design.size10Medium)
            .textCase(.uppercase)
            .tracking(1)
            .foregroundStyle(.secondary)
            .padding(.bottom, 6)
    }
}

#Preview {
    CustomAccountFormView(
        store: Store(initialState: CustomAccountFormFeature.State()) {
            CustomAccountFormFeature()
        }
    )
    .padding(.top, 40)
}
