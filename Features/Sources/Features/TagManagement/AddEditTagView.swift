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
            ZStack {
                WarmGradientBackground(variant: .top)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 22) {
                        livePreviewHero
                        nameSection
                        colorSection

                        Text("tag_form_usage_hint")
                            .font(Font.Design.size11)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 60)
                }
            }
            .navigationTitle(store.navigationTitle)
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
        return HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text("#\(store.name.isEmpty ? String(localized: "tag_form_name_placeholder") : store.name)")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(color)
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 20)
        .background(color.opacity(0.13), in: Capsule())
        .overlay(Capsule().strokeBorder(color, lineWidth: 1.5))
        .shadow(color: color.opacity(0.3), radius: 12, x: 0, y: 8)
        .padding(.top, 16)
        .padding(.bottom, 4)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Name Section

    private var nameSection: some View {
        sectionGroup(label: "common_name") {
            VStack(alignment: .leading, spacing: 6) {
                GlassContainer(cornerRadius: 12, padding: 14) {
                    HStack(spacing: 6) {
                        Text("#")
                            .font(Font.Design.body.weight(.semibold))
                            .foregroundStyle(.secondary)
                        TextField(
                            String(localized: "tag_form_name_placeholder"),
                            text: Binding(
                                get: { store.name },
                                set: { store.send(.nameChanged($0)) }
                            )
                        )
                        .font(Font.Design.body)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    }
                }
                if let error = store.nameError {
                    ErrorText(error)
                        .padding(.horizontal, 4)
                }
            }
        }
    }

    // MARK: - Color Section

    private var colorSection: some View {
        sectionGroup(label: "common_color") {
            GlassContainer(cornerRadius: 14, padding: 14) {
                ColorSwatchPicker(
                    colors: DesignConstants.tagColorOptions,
                    selectedHex: store.colorHex,
                    layout: .grid(columns: 6),
                    onSelect: { store.send(.colorHexChanged($0)) }
                )
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
}

#Preview("Add") {
    AddEditTagView(
        store: Store(initialState: AddEditTagFeature.State(mode: .add)) {
            AddEditTagFeature()
        }
    )
}

#Preview("Edit") {
    AddEditTagView(
        store: Store(initialState: AddEditTagFeature.State(
            mode: .edit(Tag(
                name: "週末聚餐",
                color: "#A66BF0"
            ))
        )) {
            AddEditTagFeature()
        }
    )
}
