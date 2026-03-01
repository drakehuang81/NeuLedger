import SwiftUI

/// A full-width, pill-shaped primary call-to-action button.
///
/// Design Spec:
/// - Background: Brand Primary (#3478F6)
/// - Corner Radius: Capsule (pill)
/// - Height: 56pt
/// - Width: Fill container
/// - Text: 17pt Semibold, White
/// - Icon: Optional trailing SF Symbol
///
/// Usage:
/// ```swift
/// PrimaryButton("Get Started", systemImage: "arrow.forward") {
///     // action
/// }
/// ```
public struct PrimaryButton: View {
    let titleKey: LocalizedStringKey
    let systemImage: String?
    let action: () -> Void

    /// Initializes a PrimaryButton with a localized title key.
    ///
    /// - Parameters:
    ///   - titleKey: A localized string key for the button title.
    ///   - systemImage: Optional trailing SF Symbol name.
    ///   - action: The closure to execute on tap.
    public init(
        _ titleKey: LocalizedStringKey,
        systemImage: String? = nil,
        action: @escaping () -> Void
    ) {
        self.titleKey = titleKey
        self.systemImage = systemImage
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(titleKey)
                    .font(Font.Design.headline)

                if let systemImage {
                    Image(systemName: systemImage)
                        .font(Font.Design.headline)
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color.Design.brandPrimary)
            .clipShape(Capsule())
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        PrimaryButton("component_get_started", systemImage: "arrow.forward") {
            print("Tapped")
        }

        PrimaryButton("component_next") {
            print("Next")
        }
    }
    .padding(.horizontal, 24)
}
