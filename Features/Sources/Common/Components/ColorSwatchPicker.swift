import SwiftUI

public enum ColorSwatchLayout {
    case horizontalScroll
    case grid(columns: Int)
}

/// A picker showing colored circle swatches with a checkmark on selection.
/// Accepts hex color strings; converts internally using Color(hex:).
public struct ColorSwatchPicker: View {
    let colors: [String]
    let selectedHex: String
    let layout: ColorSwatchLayout
    let onSelect: (String) -> Void

    public init(
        colors: [String],
        selectedHex: String,
        layout: ColorSwatchLayout = .horizontalScroll,
        onSelect: @escaping (String) -> Void
    ) {
        self.colors = colors
        self.selectedHex = selectedHex
        self.layout = layout
        self.onSelect = onSelect
    }

    public var body: some View {
        switch layout {
        case .horizontalScroll:
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(colors, id: \.self) { hex in colorSwatch(hex: hex) }
                }
                .padding(.vertical, 8)
            }
        case .grid(let columns):
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: columns),
                spacing: 12
            ) {
                ForEach(colors, id: \.self) { hex in colorSwatch(hex: hex) }
            }
            .padding(.vertical, 4)
        }
    }

    private func colorSwatch(hex: String) -> some View {
        let isSelected = selectedHex == hex
        return Button {
            onSelect(hex)
        } label: {
            ZStack {
                Circle()
                    .fill(Color(hex: hex))
                    .frame(width: 36, height: 36)
                if isSelected {
                    Circle()
                        .strokeBorder(Color.Design.textInverse, lineWidth: 2.5)
                        .frame(width: 36, height: 36)
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.Design.textInverse)
                        .font(.system(size: 12, weight: .bold))
                }
            }
        }
        .buttonStyle(.plain)
        .frame(width: 44, height: 44)
        .overlay {
            if isSelected {
                Circle()
                    .strokeBorder(Color(hex: hex), lineWidth: 2)
                    .frame(width: 42, height: 42)
            }
        }
    }
}
