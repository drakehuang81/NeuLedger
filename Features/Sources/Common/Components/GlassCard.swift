import SwiftUI

/// A container view with a Liquid Glass background.
///
/// This serves as the primary container for discrete content sections,
/// like account balances, transaction lists, or charts.
///
/// Usage:
/// ```
/// GlassCard {
///     Text("Title")
///     Text("Content")
/// }
/// ```
public struct GlassCard<Content: View>: View {
    let content: Content
    var cornerRadius: CGFloat
    
    /// Initializes a GlassCard.
    ///
    /// - Parameters:
    ///   - cornerRadius: The corner radius of the card. Defaults to 12.
    ///   - content: The content to display inside the card.
    public init(
        cornerRadius: CGFloat = 12,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            content
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(
            Glass.clear
                .interactive()
                .tint(Color.Design.background),
            in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
    }
}

#Preview {
    ZStack {
        Color.white
        GlassCard(cornerRadius: 12) {
            Text("component_hello")
        }.padding(.all, 20)
    }
}
