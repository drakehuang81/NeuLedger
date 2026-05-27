import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Internal Hex Helper
//
// File-private: the only sanctioned entry point for hex → Color conversion
// is `Color.Design.fromHex(_:)` (for runtime values stored as hex strings,
// e.g. SwiftData `SDAccount.color`, `SDCategory.color`, `SDTag.color`).
// Static design tokens must live as named members of `Color.Design`.
fileprivate extension Color {
    init(hexLiteral hex: String) {
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

        /// Runtime conversion of a hex string (e.g. stored on a domain model)
        /// into a `Color`. **The only public hex API.** Use a named token if
        /// the color is a design constant.
        public static func fromHex(_ hex: String) -> Color {
            Color(hexLiteral: hex)
        }

        /// Creates a dynamic color that automatically adapts to Light and Dark mode.
        private static func dynamicColor(light: String, dark: String) -> Color {
            #if os(iOS) || os(tvOS)
            return Color(uiColor: UIColor { traitCollection in
                if traitCollection.userInterfaceStyle == .dark {
                    return UIColor(Color(hexLiteral: dark))
                } else {
                    return UIColor(Color(hexLiteral: light))
                }
            })
            #elseif canImport(AppKit)
            return Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
                if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                    return NSColor(Color(hexLiteral: dark))
                } else {
                    return NSColor(Color(hexLiteral: light))
                }
            }))
            #else
            return Color(hexLiteral: light)
            #endif
        }

        // MARK: - Brand Colors
        public static let brandPrimary = Color(hexLiteral: "#3478F6")
        public static let brandSecondary = Color(hexLiteral: "#5856D6")
        public static let brandAccent = Color(hexLiteral: "#FF9500")
        public static let brandSurface = Color(hexLiteral: "#F0F4FF")
        /// Hot pink used in app-icon fallback gradients (e.g. AvatarBadge, AppIconBadge fallback).
        public static let brandPink = Color(hexLiteral: "#FF2D55")

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

        // MARK: - Settings-tile Icon Palette
        // Flat (non-adaptive) chrome colors that match the iOS Settings look.
        // Use only for the SettingsView icon tiles or equivalently chromed UI.
        public static let iconCyan   = Color(hexLiteral: "#5AC8FA")
        public static let iconPurple = Color(hexLiteral: "#AF52DE")
        public static let iconGray   = Color(hexLiteral: "#8E8E93")
        public static let iconBlueAlt = Color(hexLiteral: "#0A84FF")

        // MARK: - Background & Surface Colors
        #if os(iOS)
        public static let background = Color(uiColor: .systemBackground)
        public static let surfaceInverse = Color(uiColor: .label)
        #else
        // watchOS has no UIColor.systemBackground / .label and is always
        // dark-themed. Use literal fallbacks that match the dark-iOS values.
        public static let background = Color.black
        public static let surfaceInverse = Color.white
        #endif
        public static let surface = dynamicColor(light: "#FFFFFF", dark: "#1C1C1E")
        public static let surfaceSecondary = dynamicColor(light: "#F2F2F7", dark: "#2C2C2E")

        // MARK: - Glassmorphism Surfaces
        public static let glassProminent = dynamicColor(light: "#FFFFFFCC", dark: "#2C2C2ECC")
        public static let glassSurface = dynamicColor(light: "#FFFFFFB3", dark: "#1C1C1EB3")

        // MARK: - Text Colors
        #if os(iOS)
        public static let textPrimary = Color(uiColor: .label)
        public static let textInverse = Color(uiColor: .systemBackground)
        #else
        public static let textPrimary = Color.white
        public static let textInverse = Color.black
        #endif
        public static let textSecondary = dynamicColor(light: "#3C3C43CC", dark: "#EBEBF5CC")
        public static let textTertiary = dynamicColor(light: "#3C3C434D", dark: "#EBEBF54D")

        // MARK: - Divider / Border
        public static let separator = dynamicColor(light: "#3C3C434A", dark: "#54545899")

        // MARK: - Warm Gradient Backdrop
        // Used by WarmGradientBackground and LoadingView for the radial backdrop.
        public static let warmBgInnerLight  = Color(hexLiteral: "#FFE4B8")
        public static let warmBgMidLight    = Color(hexLiteral: "#FFF6E8")
        public static let warmBgOuterLight  = Color(hexLiteral: "#FAFAF7")
        /// WarmGradientBackground 的 dark 變體（深度最深，呼應 ambient orb 設計）
        public static let warmBgInnerDeepDark  = Color(hexLiteral: "#4A2A0E")
        public static let warmBgMidDeepDark    = Color(hexLiteral: "#1A0F08")
        public static let warmBgOuterDeepDark  = Color(hexLiteral: "#050505")
        /// LoadingView 的 dark 變體（深度較淺，與 LaunchBackground 深色版銜接）
        public static let splashBgInnerDark = Color(hexLiteral: "#2A1F18")
        public static let splashBgMidDark   = Color(hexLiteral: "#1A1410")
        public static let splashBgOuterDark = Color(hexLiteral: "#0A0806")

        // MARK: - Splash / Loading Tokens
        public static let splashOrbOrange = Color(hexLiteral: "#FF9500")
        public static let splashOrbGreen  = Color(hexLiteral: "#34C759")
        public static let splashOrbYellow = Color(hexLiteral: "#FFD27A")
        public static let splashProgressEnd = Color(hexLiteral: "#FF6A00")
        public static let splashTextPrimaryLight   = Color(hexLiteral: "#0A0A0A")
        public static let splashTextPrimaryDark    = Color(hexLiteral: "#F4E4C8")
        public static let splashTextSecondaryLight = Color(hexLiteral: "#3C3C43")
        public static let splashStatusFinalGreen   = Color(hexLiteral: "#34C759")

        // MARK: - LedgerCut Icon Palette
        public static let ledgerCutNoirGradient1 = Color(hexLiteral: "#1A1410")
        public static let ledgerCutNoirGradient2 = Color(hexLiteral: "#0A0806")
        public static let ledgerCutNoirGradient3 = Color(hexLiteral: "#000000")
        public static let ledgerCutChalkGradient1 = Color(hexLiteral: "#FAF7F2")
        public static let ledgerCutChalkGradient2 = Color(hexLiteral: "#F2EDE3")
        public static let ledgerCutChalkGradient3 = Color(hexLiteral: "#E8DFD0")
        public static let ledgerCutNoirFg     = Color(hexLiteral: "#F4E4C8")
        public static let ledgerCutChalkFg    = Color(hexLiteral: "#1A1410")
        public static let ledgerCutNoirAccent  = Color(hexLiteral: "#FFB880")
        public static let ledgerCutChalkAccent = Color(hexLiteral: "#A55530")
    }
}
