import SwiftUI
import DesignTokens

/// A generic container with a glassmorphism background effect.
///
/// Use this container to wrap content that needs a blurred background and rounded corners,
/// consistent with the "NeuLedger" design language.
///
/// Design Spec:
/// - Corner Radius: 20 (xl)
/// - Background: Glass Surface (Blur + Tint)
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
            .background(.ultraThinMaterial)
            .environment(\.colorScheme, .dark) // Optional: Force dark mode for glass effect pop? Or should it adapt?
            // Design implies "glass-surface" fill. Usually implies light tint in light mode and dark tint in dark mode.
            // But strict glassmorphism often looks best with forced blur style.
            // I'll stick to adaptive material for now.
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            // Optional: Border or Shadow
             .overlay(
                 RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                     .stroke(Color.white.opacity(0.1), lineWidth: 1)
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
                Text("Default Container")
                    .foregroundStyle(.white)
            }
            
            GlassContainer(padding: 32) {
                VStack(alignment: .leading) {
                    Text("More Padding")
                        .font(.headline)
                    Text("Subtitle here")
                        .font(.caption)
                }
                .foregroundStyle(.white)
            }
        }
    }
}
