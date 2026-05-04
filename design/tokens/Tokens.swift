//  NeuLedger · Design Tokens · v1.0 (B1 · Warm)
//  Generated from prototypes/NeuLedger Design Tokens.html
//  Drop into your SwiftUI target.

import SwiftUI

// MARK: - Color helper
extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red:   Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >>  8) & 0xFF) / 255,
            blue:  Double( hex        & 0xFF) / 255,
            opacity: alpha
        )
    }
}

// MARK: - Palette
enum NLColor {
    // Accent
    static let accent       = Color(hex: 0xFF9500)
    static let accentDark   = Color(hex: 0xFF9F0A)
    static let accentSoft   = Color(hex: 0xFFD27A)

    // Semantic
    static let income       = Color(hex: 0x34C759)
    static let incomeDark   = Color(hex: 0x30D158)
    static let expense      = Color(hex: 0xFF3B30)
    static let expenseDark  = Color(hex: 0xFF453A)

    // Account types
    static let accCash      = Color(hex: 0x8E8E93)
    static let accBank      = Color(hex: 0x0A84FF)
    static let accEwallet   = Color(hex: 0x5E5CE6)
    static let accCredit    = Color(hex: 0xFF2D55)
    static let accSavings   = Color(hex: 0x34C759)

    // Surface
    static let canvas       = Color(hex: 0xFAF7F2)
    static let canvasDark   = Color(hex: 0x1A1714)
    static let ink          = Color(hex: 0x0A0A0A)
    static let inkDark      = Color.white
    static let mutedLight   = Color(hex: 0x3C3C43, alpha: 0.65)
    static let mutedDark    = Color(hex: 0xEBEBF5, alpha: 0.65)

    // Warm bg stops
    static let bgWarm1      = Color(hex: 0xFFE4B8)
    static let bgWarm2      = Color(hex: 0xFFF6E8)
    static let bgWarm3      = Color(hex: 0xFAFAF7)
    static let bgWarmD1     = Color(hex: 0x4A2A0E)
    static let bgWarmD2     = Color(hex: 0x1A0F08)
    static let bgWarmD3     = Color(hex: 0x050505)
}

// MARK: - Gradients
enum NLGradient {
    /// Primary CTA gradient — always 135°.
    static let cta = LinearGradient(
        colors: [Color(hex: 0xFF9500), Color(hex: 0xFF6A00)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Warm radial — light mode page bg.
    static let warmLight = RadialGradient(
        colors: [NLColor.bgWarm1, NLColor.bgWarm2, NLColor.bgWarm3],
        center: UnitPoint(x: 0.2, y: 0.0),
        startRadius: 0,
        endRadius: 800
    )

    /// Warm radial — dark mode page bg.
    static let warmDark = RadialGradient(
        colors: [NLColor.bgWarmD1, NLColor.bgWarmD2, NLColor.bgWarmD3],
        center: UnitPoint(x: 0.5, y: 0.3),
        startRadius: 0,
        endRadius: 900
    )
}

// MARK: - Typography
enum NLFont {
    // Family names (must be registered in Info.plist UIAppFonts)
    static let displayName = "BricolageGrotesque"
    static let bodyName    = "DMSans"
    static let monoName    = "DMMono"

    // Display
    static let displayXl = Font.custom(displayName, size: 56).weight(.bold)   // ls -1.8, lh 1.0
    static let displayL  = Font.custom(displayName, size: 40).weight(.bold)   // ls -1.2, lh 1.05
    static let displayM  = Font.custom(displayName, size: 24).weight(.bold)   // ls -0.6, lh 1.1
    static let displayS  = Font.custom(displayName, size: 18).weight(.semibold)

    // Body
    static let bodyL = Font.custom(bodyName, size: 16)
    static let bodyM = Font.custom(bodyName, size: 14)
    static let bodyS = Font.custom(bodyName, size: 12)

    // Mono
    static let monoL = Font.custom(monoName, size: 38).weight(.medium)        // ls -1.2
    static let monoM = Font.custom(monoName, size: 14).weight(.medium)        // ls -0.2
    static let monoEyebrow = Font.custom(monoName, size: 10).weight(.medium)  // UPPERCASE, ls +1.4
}

// SwiftUI doesn't have a per-font letter-spacing token; use `.tracking(_:)` modifier.
enum NLTracking {
    static let displayXl: CGFloat = -1.8
    static let displayL:  CGFloat = -1.2
    static let displayM:  CGFloat = -0.6
    static let displayS:  CGFloat = -0.3
    static let bodyL:     CGFloat = -0.15
    static let bodyM:     CGFloat = -0.1
    static let monoL:     CGFloat = -1.2
    static let monoM:     CGFloat = -0.2
    static let monoEyebrow: CGFloat = 1.4
}

// MARK: - Spacing (8pt baseline)
enum NLSpace {
    static let s1: CGFloat = 4
    static let s2: CGFloat = 8
    static let s3: CGFloat = 12
    static let s4: CGFloat = 16
    static let s5: CGFloat = 20
    static let s6: CGFloat = 24
    static let s7: CGFloat = 32
    static let s8: CGFloat = 40
    static let s9: CGFloat = 56
}

// MARK: - Radius
enum NLRadius {
    static let tap:   CGFloat = 8
    static let chip:  CGFloat = 12
    static let input: CGFloat = 16
    static let glass: CGFloat = 20
    static let card:  CGFloat = 22
    static let pill:  CGFloat = 999
    static let phone: CGFloat = 50
}

// MARK: - Shadows
struct NLShadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat

    static let glassLight = NLShadow(color: Color(hex: 0xB48C64, alpha: 0.10), radius: 24, x: 0, y: 8)
    static let glassDark  = NLShadow(color: Color.black.opacity(0.40),         radius: 24, x: 0, y: 8)
    static let cta        = NLShadow(color: Color(hex: 0xFF9500, alpha: 0.35), radius: 28, x: 0, y: 10)
    static let ctaSoft    = NLShadow(color: Color(hex: 0xFF9500, alpha: 0.34), radius: 18, x: 0, y: 6)
    static let card       = NLShadow(color: Color(hex: 0xB48C64, alpha: 0.25), radius: 80, x: 0, y: 30)
}

extension View {
    func nlShadow(_ s: NLShadow) -> some View {
        self.shadow(color: s.color, radius: s.radius, x: s.x, y: s.y)
    }
}

// MARK: - Motion
enum NLMotion {
    // Animations
    static let std    = Animation.timingCurve(0.22, 0.9, 0.32, 1, duration: 0.32)
    static let stdFast = Animation.timingCurve(0.22, 0.9, 0.32, 1, duration: 0.18)
    static let stdReveal = Animation.timingCurve(0.22, 0.9, 0.32, 1, duration: 0.48)
    static let soft   = Animation.timingCurve(0.4, 0, 0.2, 1, duration: 0.32)

    // Spring (preferred for tap/sheet — closer to native iOS feel)
    static let tapSpring = Animation.spring(response: 0.18, dampingFraction: 0.7)
    static let sheetSpring = Animation.spring(response: 0.32, dampingFraction: 0.85)
}

// MARK: - Glass surface modifier
struct GlassCard: ViewModifier {
    let dark: Bool
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: NLRadius.glass, style: .continuous)
                    .fill(dark ? Color.white.opacity(0.08) : Color.white.opacity(0.55))
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: NLRadius.glass, style: .continuous))
            )
            .overlay(
                RoundedRectangle(cornerRadius: NLRadius.glass, style: .continuous)
                    .strokeBorder(
                        dark ? Color.white.opacity(0.12) : Color.white.opacity(0.7),
                        lineWidth: 0.5
                    )
            )
            .nlShadow(dark ? NLShadow.glassDark : NLShadow.glassLight)
    }
}

extension View {
    func glassCard(dark: Bool = false) -> some View { modifier(GlassCard(dark: dark)) }
}
