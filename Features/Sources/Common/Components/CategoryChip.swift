import SwiftUI

/// A small pill-shaped chip representing a category.
///
/// Design Spec:
/// - Corner Radius: Pill (Capsule)
/// - Background: Glass Surface (UltraThin Material)
/// - Padding: Horizontal 14, Vertical 8
/// - Gap: 6
/// - Icon: 16x16
///
/// When `isSelected` is `true`, a 2pt `brandPrimary` border is applied around the capsule.
/// When `isSuggested` is `true`, a sparkle badge is shown in the top-leading corner.
public struct CategoryChip: View {
    let title: String
    let icon: String // System name
    let color: Color // Icon color
    let isSelected: Bool
    let isSuggested: Bool

    public init(
        title: String,
        systemImage: String,
        color: Color = .primary,
        isSelected: Bool = false,
        isSuggested: Bool = false
    ) {
        self.title = title
        self.icon = systemImage
        self.color = color
        self.isSelected = isSelected
        self.isSuggested = isSuggested
    }

    public var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16)) // 16x16
                .foregroundStyle(color)

            Text(title)
                .font(Font.Design.caption.weight(.medium)) // 13pt Medium
                .foregroundStyle(Color.Design.textPrimary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 14)
        .glassEffect(Glass.clear.interactive().tint(Color.Design.background), in: Capsule())
        .overlay {
            if isSelected {
                Capsule()
                    .strokeBorder(Color.Design.brandPrimary, lineWidth: 2)
            }
        }
        .overlay(alignment: .topLeading) {
            if isSuggested {
                Image(systemName: "sparkles")
                    .font(.caption2)
                    .foregroundStyle(Color.Design.brandPrimary)
                    .offset(x: 4, y: -4)
            }
        }
    }
}

#Preview {
    ZStack {
        Color.gray.ignoresSafeArea()
        
        CategoryChip(
            title: String(localized: "component_food_and_dining"),
            systemImage: "fork.knife",
            color: .orange
        )
    }
}
