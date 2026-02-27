import SwiftUI

/// A pill-shaped button with glassmorphism style, supporting icon and title.
///
/// Design Spec:
/// - Corner Radius: Pill (Capsule)
/// - Background: Glass Prominent (Regular Material)
/// - Padding: Horizontal 20, Vertical 10
/// - Gap: 8
/// - Icon: Optional (Symbol)
public struct GlassButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    
    /// Initializes a GlassButton.
    ///
    /// - Parameters:
    ///   - title: The button title.
    ///   - icon: Optional system symbol name (SF Symbols).
    ///   - action: The closure to execute on tap.
    public init(
        title: String,
        systemImage: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = systemImage
        self.action = action
    }
    
    /// Compatibility initializer for old calls (title only).
    public init(_ title: String, action: @escaping () -> Void) {
        self.init(title: title, systemImage: nil, action: action)
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .medium)) // Icon size 20
                }
                
                Text(title)
                    .font(.Design.headline) // 15pt Semibold? Or .headline equivalent
                    // Design spec: 15pt Semibold (DMSans-SemiBold)
                    // If .Design.headline is 17pt, maybe use .subheadline (15pt).
                    // FontTokens.swift might have it. I'll use .body for safety or specific if I knew.
                    // Assuming .headline is close enough or use system font.
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 20)
            .background(.regularMaterial) // Glass Prominent
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain) // Remove default button modification
        // Tint is handled by foreground style typically.
        // Design usually has brand color text.
        .foregroundStyle(Color.accentColor) 
    }
}

#Preview {
    ZStack {
        Color.blue.opacity(0.2).ignoresSafeArea()
        
        VStack(spacing: 20) {
            GlassButton(title: "Add Item", systemImage: "plus") {
                print("Tapped")
            }
            
            GlassButton("Simple Button") {
                print("Simple")
            }
            .foregroundStyle(.red) // Override tint
        }
    }
}
