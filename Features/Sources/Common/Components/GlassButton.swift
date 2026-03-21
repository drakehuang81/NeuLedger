import SwiftUI

/// A pill-shaped button with glassmorphism style, supporting icon and title.
///
/// Design Spec:
/// - Corner Radius: Pill (Capsule)
/// - Style: .buttonStyle(.glass)
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
                    .font(Font.Design.headline)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 20)
        }
        .buttonStyle(.glass)
        .foregroundStyle(Color.Design.brandPrimary)
    }
}

#Preview {
    ZStack {
        Color.blue.opacity(0.2).ignoresSafeArea()
        
        VStack(spacing: 20) {
            GlassButton(title: "component_add_item", systemImage: "plus") {
                print("Tapped")
            }
            
            GlassButton(String(localized: "component_simple_button")) {
                print("Simple")
            }
            .foregroundStyle(.red) // Override tint
        }
    }
}
