import Common
import ComposableArchitecture
import Domain
import SwiftUI

private func hexColor(_ hex: String) -> Color {
    let h = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
    var int: UInt64 = 0
    Scanner(string: h).scanHexInt64(&int)
    let a: UInt64 = 255
    let r = int >> 16
    let g = int >> 8 & 0xFF
    let b = int & 0xFF
    return Color(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
}

public struct AddEditTagView: View {
    @Bindable var store: StoreOf<AddEditTagFeature>

    private let colorOptions: [String] = [
        "#FF3B30", "#FF9500", "#FFCC00", "#34C759",
        "#00C7BE", "#32ADE6", "#007AFF", "#5856D6",
        "#AF52DE", "#FF2D55", "#3478F6", "#8E8E93"
    ]

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
                    colorPickerGrid
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

    // MARK: - Color Picker Grid

    private var colorPickerGrid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 6),
            spacing: 12
        ) {
            ForEach(colorOptions, id: \.self) { hex in
                colorCircle(hex: hex)
            }
        }
        .padding(.vertical, 4)
    }

    private func colorCircle(hex: String) -> some View {
        let isSelected = store.colorHex == hex
        return Button {
            store.send(.colorHexChanged(hex))
        } label: {
            ZStack {
                Circle()
                    .fill(hexColor(hex))
                    .frame(width: 36, height: 36)

                if isSelected {
                    Circle()
                        .strokeBorder(Color.Design.textPrimary.opacity(0.3), lineWidth: 2)
                        .frame(width: 40, height: 40)

                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.Design.textInverse)
                }
            }
        }
        .buttonStyle(.plain)
        .frame(width: 44, height: 44)
    }
}
