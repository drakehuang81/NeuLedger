import SwiftUI

/// A colored circle containing an SF Symbol.
/// Used for entity previews (account, category) and list rows.
public struct IconBadge: View {
    let systemImage: String
    let color: Color
    let size: CGFloat

    public init(systemImage: String, color: Color, size: CGFloat = 44) {
        self.systemImage = systemImage
        self.color = color
        self.size = size
    }

    public var body: some View {
        ZStack {
            Circle()
                .fill(color)
                .frame(width: size, height: size)
            Image(systemName: systemImage)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.Design.textInverse)
                .font(.system(size: size * 0.45, weight: .medium))
        }
    }
}
