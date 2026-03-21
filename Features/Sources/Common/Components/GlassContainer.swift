import SwiftUI

/// A generic container with a glassmorphism background effect.
///
/// Use this container to wrap content that needs a blurred background and rounded corners,
/// consistent with the "NeuLedger" design language.
///
/// Design Spec:
/// - Corner Radius: 20 (xl)
/// - Background: iOS 26 Liquid Glass (.glassEffect)
/// - Padding: 16 (default)
public struct GlassContainer<Content: View>: View {
    private let content: Content
    private let padding: EdgeInsets
    private let cornerRadius: CGFloat
    
    /// Initializes a generic GlassContainer.
    ///
    /// - Parameters:
    ///   - cornerRadius: The corner radius of the container. Defaults to 20.
    ///   - padding: Internal padding for the content.
    ///   - content: The content to maintain inside the glass container.
    public init(
        cornerRadius: CGFloat = 20,
        padding: EdgeInsets,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.content = content()
    }
    
    /// Convenience initializer with uniform padding.
    public init(
        cornerRadius: CGFloat = 20,
        padding: CGFloat = 16,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            cornerRadius: cornerRadius,
            padding: EdgeInsets(top: padding, leading: padding, bottom: padding, trailing: padding),
            content: content
        )
    }

    public var body: some View {
        content
            .padding(padding)
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
        // Background to show glass effect
        LinearGradient(
            colors: [.blue, .purple],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        
        VStack(spacing: 20) {
            GlassContainer {
                Text("component_default_container")
                    .foregroundStyle(.white)
            }
            
            GlassContainer(padding: 32) {
                VStack(alignment: .leading) {
                    Text("component_more_padding")
                        .font(.headline)
                    Text("component_subtitle_here")
                        .font(.caption)
                }
                .foregroundStyle(.white)
            }
        }
    }
}
