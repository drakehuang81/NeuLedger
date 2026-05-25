import SwiftUI
import UIKit

/// Displays the host app's primary icon as a circular badge.
///
/// Reads `CFBundleIcons` from the main bundle at runtime so the badge always
/// reflects the currently shipped app icon without bundling a duplicate asset
/// inside the Features package. Falls back to a SF Symbol if lookup fails
/// (e.g. in SwiftUI previews where `Bundle.main` has no icon entries).
public struct AppIconBadge: View {
    public var size: CGFloat

    public init(size: CGFloat = 36) {
        self.size = size
    }

    public var body: some View {
        Group {
            if let image = Self.appIconImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    LinearGradient(
                        colors: [Color.Design.brandPrimary, Color.Design.brandPink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Image(systemName: "wallet.pass.fill")
                        .font(Font.Design.dynamic(size: size * 0.42, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
        }
        .shadow(color: Color.black.opacity(0.18), radius: 6, x: 0, y: 3)
    }

    private static var appIconImage: UIImage? {
        guard
            let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
            let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
            let files = primary["CFBundleIconFiles"] as? [String],
            let lastName = files.last
        else { return nil }
        return UIImage(named: lastName)
    }
}

#Preview {
    AppIconBadge().padding()
}
