import SwiftUI

/// A small pill-shaped chip representing a category.
///
/// Design Spec:
/// - Corner Radius: Pill (Capsule)
/// - Background: Glass Surface (UltraThin Material)
/// - Padding: Horizontal 14, Vertical 8
/// - Gap: 6
/// - Icon: 16x16
public struct CategoryChip: View {
    let title: String
    let icon: String // System name
    let color: Color // Icon color
    
    public init(
        title: String,
        systemImage: String,
        color: Color = .primary
    ) {
        self.title = title
        self.icon = systemImage
        self.color = color
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
        .background(.ultraThinMaterial) // Glass Surface
        .clipShape(Capsule())
        // Optional border
        .overlay(
            Capsule().stroke(Color.white.opacity(0.1), lineWidth: 0.5)
        )
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
