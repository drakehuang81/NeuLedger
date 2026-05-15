import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - SwiftUI Color Hex Helper
public extension Color {
    init(hex: String) {
        let hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        var int: UInt64 = 0
        Scanner(string: hexString).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hexString.count {
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // RRGGBBAA (32-bit)
            (r, g, b, a) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Design System Colors
public extension Color {
    enum Design {
        
        /// Creates a dynamic color that automatically adapts to Light and Dark mode.
        /// (Uses platform-specific dynamic color bridging under the hood)
        private static func dynamicColor(light: String, dark: String) -> Color {
            #if canImport(UIKit)
            return Color(uiColor: UIColor { traitCollection in
                if traitCollection.userInterfaceStyle == .dark {
                    // We must convert back from SwiftUI Color to UIColor/NSColor for the closure
                    return UIColor(Color(hex: dark))
                } else {
                    return UIColor(Color(hex: light))
                }
            })
            #elseif canImport(AppKit)
            return Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
                if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                    return NSColor(Color(hex: dark))
                } else {
                    return NSColor(Color(hex: light))
                }
            }))
            #else
            return Color(hex: light)
            #endif
        }
        
        // MARK: - Brand Colors
        public static let brandPrimary = Color(hex: "#3478F6")
        public static let brandSecondary = Color(hex: "#5856D6")
        public static let brandAccent = Color(hex: "#FF9500")
        public static let brandSurface = Color(hex: "#F0F4FF")
        
        // MARK: - Accent & Semantic Colors
        public static let accentBlue = dynamicColor(light: "#007AFF", dark: "#0A84FF")
        public static let accentGreen = dynamicColor(light: "#34C759", dark: "#30D158")
        public static let accentOrange = dynamicColor(light: "#FF9500", dark: "#FF9F0A")
        public static let accentRed = dynamicColor(light: "#FF3B30", dark: "#FF453A")
        public static let accentYellow = dynamicColor(light: "#FFCC00", dark: "#FFD60A")
        
        public static let incomeGreen = accentGreen
        public static let expenseRed = accentRed
        public static let warningAmber = accentOrange

        /// Transfer 用紫（暖系，對齊設計 token `accInvest`）
        public static let transferPurple = dynamicColor(light: "#5E5CE6", dark: "#7D7AFF")
        /// AI 標誌色（sparkles / AI suggestion badge）
        public static let aiPurple = dynamicColor(light: "#A66BF0", dark: "#BF8DFF")
        
        // MARK: - Background & Surface Colors
        public static let background = Color(uiColor: .systemBackground)
        public static let surface = dynamicColor(light: "#FFFFFF", dark: "#1C1C1E")
        public static let surfaceSecondary = dynamicColor(light: "#F2F2F7", dark: "#2C2C2E")
        public static let surfaceInverse = Color(uiColor: .label)

        // MARK: - Glassmorphism Surfaces
        public static let glassProminent = dynamicColor(light: "#FFFFFFCC", dark: "#2C2C2ECC")
        public static let glassSurface = dynamicColor(light: "#FFFFFFB3", dark: "#1C1C1EB3")

        // MARK: - Text Colors
        public static let textPrimary = Color(uiColor: .label)
        public static let textSecondary = dynamicColor(light: "#3C3C43CC", dark: "#EBEBF5CC")
        public static let textTertiary = dynamicColor(light: "#3C3C434D", dark: "#EBEBF54D")
        public static let textInverse = Color(uiColor: .systemBackground)
        
        // MARK: - Divider / Border
        public static let separator = dynamicColor(light: "#3C3C434A", dark: "#54545899")
    }
}
