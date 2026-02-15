import SwiftUI
import DesignTokens

/// A header view for list sections or content groups.
///
/// Designed to be used with `GlassCard` or `Section` views.
/// Displays a title and an optional trailing action (like "View All").
///
/// Usage:
/// ```
/// GlassHeader(title: "Transactions", action: Button(...) { ... })
/// ```
public struct GlassHeader<Action: View>: View {
    let title: String
    let subtitle: String?
    let action: Action?
    
    /// Initializes a header with a title and optional action.
    ///
    /// - Parameters:
    ///   - title: The main title text.
    ///   - subtitle: Optional subtitle text.
    ///   - action: Optional trailing view (usually a Button or Link).
    public init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder action: () -> Action? = { nil }
    ) {
        self.title = title
        self.subtitle = subtitle
        self.action = action()
    }
    
    public var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.Design.title2)
                    .foregroundStyle(Color.Design.textPrimary)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.Design.subheadline)
                        .foregroundStyle(Color.Design.textSecondary)
                }
            }
            
            Spacer()
            
            if let action = action {
                action
            }
        }
        .padding(.horizontal, 4) // Slight inset for headers
        .padding(.bottom, 8)
    }
}

// Convenience init for no-action header
public extension GlassHeader where Action == EmptyView {
    init(title: String, subtitle: String? = nil) {
        self.init(title: title, subtitle: subtitle, action: { EmptyView() })
    }
}

#Preview {
    GlassHeader(title: "This is a test title", subtitle: "This is a test subtitle")
        .padding(.all, 20)
}
