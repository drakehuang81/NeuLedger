import SwiftUI

/// A horizontal scrolling row of SF Symbol icon buttons with selection state.
/// Selected icon shows opaque accent fill with textInverse icon.
public struct IconPickerRow: View {
    let icons: [String]
    let selectedIcon: String
    let accentColor: Color
    let onSelect: (String) -> Void

    public init(
        icons: [String],
        selectedIcon: String,
        accentColor: Color,
        onSelect: @escaping (String) -> Void
    ) {
        self.icons = icons
        self.selectedIcon = selectedIcon
        self.accentColor = accentColor
        self.onSelect = onSelect
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(icons, id: \.self) { iconName in
                    iconButton(iconName: iconName)
                }
            }
            .padding(.vertical, 8)
        }
    }

    private func iconButton(iconName: String) -> some View {
        let isSelected = selectedIcon == iconName
        return Button {
            onSelect(iconName)
        } label: {
            ZStack {
                Circle()
                    .fill(isSelected ? accentColor : Color.Design.surfaceSecondary)
                    .frame(width: 44, height: 44)
                    .overlay {
                        if isSelected {
                            Circle().strokeBorder(accentColor, lineWidth: 2)
                        }
                    }
                Image(systemName: iconName)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isSelected ? Color.Design.textInverse : Color.Design.textSecondary)
                    .font(Font.Design.size18Medium)
            }
        }
        .buttonStyle(.plain)
    }
}
