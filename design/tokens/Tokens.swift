// NeuLedger · Design Tokens · v2.0 (B1 Warm Glass)
// Locked-in direction as of May 15, 2026
// Drop into your SwiftUI target. Generated from current prototypes.

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
    // Accent — Warm orange (B1)
    static let accent       = Color(hex: 0xE8835A)   // light mode
    static let accentDark   = Color(hex: 0xFF6A00)   // dark mode

    // Semantic
    static let income       = Color(hex: 0x34C759)
    static let expense      = Color(hex: 0xFF453A)
    static let ai           = Color(hex: 0xA66BF0)   // AI / on-device extraction purple

    // Account-type accent (used as icon + edge color)
    static let accCash      = Color(hex: 0x9B7E5F)
    static let accBank      = Color(hex: 0x1B5E8E)
    static let accCredit    = Color(hex: 0x7B3F00)
    static let accDigital   = Color(hex: 0x000000)
    static let accJko       = Color(hex: 0xFF6B6B)
    static let accInvest    = Color(hex: 0x5E5CE6)

    // Frequency-pill colors (recurring tx, budget periods)
    static let freqWeekly   = Color(hex: 0x0A84FF)
    static let freqMonthly  = Color(hex: 0xE8835A)
    static let freqYearly   = Color(hex: 0xA66BF0)

    // Tag palette (Tag Management swatches)
    static let tagSwatches: [Color] = [
        Color(hex: 0x3478F6), Color(hex: 0xE8835A), Color(hex: 0x7B3F00),
        Color(hex: 0xA66BF0), Color(hex: 0x0A84FF), Color(hex: 0x5E5CE6),
        Color(hex: 0x34C759), Color(hex: 0xFF453A), Color(hex: 0xFF6B6B),
        Color(hex: 0xF4B400), Color(hex: 0x8B6F47), Color(hex: 0x9B7E5F),
    ]

    // Surface
    static let canvas       = Color(hex: 0xECE9E2)   // Canvas color shown around the phone frame
    static let ink          = Color(hex: 0x0A0A0A)
    static let inkDark      = Color.white
    static let mutedLight   = Color(hex: 0x3C3C43, alpha: 0.55)
    static let mutedDark    = Color(hex: 0xEBEBF5, alpha: 0.55)
    static let dividerLight = Color.black.opacity(0.05)
    static let dividerDark  = Color.white.opacity(0.06)
}

// MARK: - Warm radial background (page bg inside phone)
enum NLGradient {
    /// Light: radial-gradient(ellipse at 50% -10%, #FFE4D2 0%, #FBF1E5 30%, #F6ECDF 60%)
    static let warmLight = RadialGradient(
        colors: [Color(hex: 0xFFE4D2), Color(hex: 0xFBF1E5), Color(hex: 0xF6ECDF)],
        center: UnitPoint(x: 0.5, y: -0.10),
        startRadius: 0,
        endRadius: 700
    )

    /// Dark: radial-gradient(ellipse at 50% -20%, #4A2A0E 0%, #1a0f08 35%, #050505 70%)
    static let warmDark = RadialGradient(
        colors: [Color(hex: 0x4A2A0E), Color(hex: 0x1A0F08), Color(hex: 0x050505)],
        center: UnitPoint(x: 0.5, y: -0.20),
        startRadius: 0,
        endRadius: 800
    )

    /// Primary CTA — warm orange gradient (light mode)
    static let cta = LinearGradient(
        colors: [Color(hex: 0xE8835A), Color(hex: 0xFF6A00)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Typography
enum NLFont {
    // Family names (must be registered in Info.plist UIAppFonts)
    static let displayName = "BricolageGrotesque"   // headings, large amounts
    static let bodyName    = "DMSans"               // body, UI text
    static let monoName    = "DMMono"               // numbers, ALL-CAPS eyebrows, tags

    // Display
    static let displayXl = Font.custom(displayName, size: 40).weight(.semibold)  // canvas titles
    static let displayL  = Font.custom(displayName, size: 34).weight(.semibold)  // hero amount
    static let displayM  = Font.custom(displayName, size: 22).weight(.semibold)
    static let displayS  = Font.custom(displayName, size: 18).weight(.semibold)
    static let navTitle  = Font.custom(displayName, size: 17).weight(.semibold)

    // Body
    static let bodyL = Font.custom(bodyName, size: 16)
    static let bodyM = Font.custom(bodyName, size: 14)
    static let bodyS = Font.custom(bodyName, size: 12)
    static let bodyXs = Font.custom(bodyName, size: 11)

    // Mono
    static let monoL = Font.custom(monoName, size: 38).weight(.medium)
    static let monoM = Font.custom(monoName, size: 14).weight(.medium)
    static let monoS = Font.custom(monoName, size: 12).weight(.medium)
    static let monoEyebrow = Font.custom(monoName, size: 11).weight(.medium)  // UPPERCASE, ls +1.2
}

// SwiftUI letter-spacing → `.tracking(_:)`
enum NLTracking {
    static let displayXl: CGFloat = -1.0
    static let displayL:  CGFloat = -1.0
    static let displayM:  CGFloat = -0.4
    static let displayS:  CGFloat = -0.3
    static let bodyL:     CGFloat = -0.1
    static let bodyM:     CGFloat = -0.05
    static let monoEyebrow: CGFloat = 1.2
}

// MARK: - Spacing (4pt baseline)
enum NLSpace {
    static let s1: CGFloat = 4
    static let s2: CGFloat = 8
    static let s3: CGFloat = 12
    static let s4: CGFloat = 16
    static let s5: CGFloat = 20
    static let s6: CGFloat = 24
    static let s7: CGFloat = 32
    static let s8: CGFloat = 40
}

// MARK: - Radius
enum NLRadius {
    static let tap:    CGFloat = 8
    static let chip:   CGFloat = 11    // small icon blocks
    static let input:  CGFloat = 14
    static let glass:  CGFloat = 18    // glass cards (lists)
    static let card:   CGFloat = 20    // hero / summary cards
    static let sheet:  CGFloat = 22    // bottom sheet top corners
    static let pill:   CGFloat = 999
    static let phone:  CGFloat = 48    // iPhone 17 Pro bezel
}

// MARK: - Shadows
struct NLShadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat

    /// Glass card surface — light
    static let glassLight = NLShadow(color: Color(hex: 0x785028, alpha: 0.06), radius: 12, x: 0, y: 4)
    /// Glass card surface — dark
    static let glassDark  = NLShadow(color: Color.black.opacity(0.35),         radius: 28, x: 0, y: 12)
    /// Primary CTA
    static let cta        = NLShadow(color: Color(hex: 0xE8835A, alpha: 0.34), radius: 20, x: 0, y: 8)
    /// Phone bezel drop
    static let phone      = NLShadow(color: Color.black.opacity(0.18),         radius: 80, x: 0, y: 40)
}

extension View {
    func nlShadow(_ s: NLShadow) -> some View {
        self.shadow(color: s.color, radius: s.radius, x: s.x, y: s.y)
    }
}

// MARK: - Motion
enum NLMotion {
    // Standard ease curves used in prototypes
    static let std       = Animation.timingCurve(0.22, 0.9, 0.32, 1, duration: 0.32)
    static let stdFast   = Animation.timingCurve(0.22, 0.9, 0.32, 1, duration: 0.18)
    static let stdReveal = Animation.timingCurve(0.22, 0.9, 0.32, 1, duration: 0.48)

    // Prefer native spring for tap / sheet
    static let tapSpring   = Animation.spring(response: 0.18, dampingFraction: 0.7)
    static let sheetSpring = Animation.spring(response: 0.32, dampingFraction: 0.85)
}

// MARK: - Frame size (mockup)
enum NLFrame {
    /// iPhone 17 Pro design frame used in all mockups
    static let width:  CGFloat = 402
    static let height: CGFloat = 874
}

// MARK: - Glass surface modifier
struct GlassCard: ViewModifier {
    var dark: Bool = false
    var radius: CGFloat = NLRadius.glass
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(dark ? Color.white.opacity(0.06) : Color.white.opacity(0.70))
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(
                        dark ? Color.white.opacity(0.10) : Color.white.opacity(0.85),
                        lineWidth: 0.5
                    )
            )
            .nlShadow(dark ? NLShadow.glassDark : NLShadow.glassLight)
    }
}

extension View {
    func glassCard(dark: Bool = false, radius: CGFloat = NLRadius.glass) -> some View {
        modifier(GlassCard(dark: dark, radius: radius))
    }
}
