import SwiftUI

/// A small pill for tags or secondary statuses.
///
/// Design Spec:
/// - Corner Radius: Pill (Capsule)
/// - Background: Surface Secondary (Grouped Background)
/// - Padding: Horizontal 10, Vertical 4
/// - Gap: 4
/// - Content: Dot (8px) + Text (12pt Medium)
public struct TagPill: View {
    let text: String
    let dotColor: Color? // Optional dot
    
    public init(
        text: String,
        color: Color? = nil
    ) {
        self.text = text
        self.dotColor = color
    }
    
    public var body: some View {
        HStack(spacing: 4) {
            if let dotColor {
                Circle()
                    .fill(dotColor)
                    .frame(width: 8, height: 8)
            }
            
            Text(text)
                .font(Font.Design.caption.weight(.medium))
                .foregroundStyle(Color.Design.textSecondary)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 10)
        .background(Color.Design.surfaceSecondary) // Surface Secondary
        .clipShape(Capsule())
    }
}

#Preview {
    VStack {
        TagPill(text: String(localized: "component_cash"), color: .green)
        TagPill(text: String(localized: "component_pending"), color: .orange)
        TagPill(text: String(localized: "component_no_color"))
    }
}
