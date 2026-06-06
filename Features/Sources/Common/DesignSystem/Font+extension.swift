import SwiftUI

public extension Font {
    enum Design {

        // MARK: - Dynamic Type Scale
        //
        // Wraps SwiftUI's Dynamic Type tokens. Use these for body text,
        // form labels, readable content — anywhere the user's text-size
        // preference should govern rendering.
        public static let headline = Font.headline
        public static let body = Font.body
        public static let callout = Font.callout
        public static let caption = Font.caption

        /// Monospaced digit body font for financial amounts (Dynamic Type).
        public static let amount = Font.body.monospacedDigit()

        /// Fully monospaced body font for code-like input (e.g. carrier
        /// barcodes) where every character must align (Dynamic Type).
        public static let bodyMonospaced = Font.body.monospaced()

        // MARK: - Fixed Pixel Scale
        //
        // Absolute-pixel sizes for chrome, badges, metric labels, hero
        // numbers — anywhere the design specifies an exact px size that
        // must NOT scale with Dynamic Type. **This is the only sanctioned
        // typography path outside Dynamic Type**: do NOT call
        // `.system(size:...)` directly anywhere in the codebase. If no
        // token fits, add one here first.

        // --- Tiny chrome (≤ 10) ---
        public static let size7Medium             = Font.system(size: 7, weight: .medium)
        public static let size8                   = Font.system(size: 8)
        public static let size9                   = Font.system(size: 9)
        public static let size9Medium             = Font.system(size: 9, weight: .medium)
        public static let size9Monospaced         = Font.system(size: 9, design: .monospaced)
        public static let size9SemiboldMonospaced = Font.system(size: 9, weight: .semibold, design: .monospaced)
        public static let size10                  = Font.system(size: 10)
        public static let size10Medium            = Font.system(size: 10, weight: .medium)
        public static let size10Bold              = Font.system(size: 10, weight: .bold)
        public static let size10Monospaced        = Font.system(size: 10, design: .monospaced)
        public static let size10MediumMonospaced  = Font.system(size: 10, weight: .medium, design: .monospaced)

        // --- Standard chrome (11–14) ---
        public static let size11                  = Font.system(size: 11)
        public static let size11Medium            = Font.system(size: 11, weight: .medium)
        public static let size11Semibold          = Font.system(size: 11, weight: .semibold)
        public static let size11Monospaced        = Font.system(size: 11, design: .monospaced)
        public static let size11MediumMonospaced  = Font.system(size: 11, weight: .medium, design: .monospaced)
        public static let size12                  = Font.system(size: 12)
        public static let size12Medium            = Font.system(size: 12, weight: .medium)
        public static let size12Semibold          = Font.system(size: 12, weight: .semibold)
        public static let size12Bold              = Font.system(size: 12, weight: .bold)
        public static let size12Monospaced        = Font.system(size: 12, design: .monospaced)
        public static let size13                  = Font.system(size: 13)
        public static let size13Medium            = Font.system(size: 13, weight: .medium)
        public static let size13Semibold          = Font.system(size: 13, weight: .semibold)
        public static let size14                  = Font.system(size: 14)
        public static let size14Medium            = Font.system(size: 14, weight: .medium)
        public static let size14Semibold          = Font.system(size: 14, weight: .semibold)

        // --- Body / heading (15–22) ---
        public static let size15                  = Font.system(size: 15)
        public static let size15Medium            = Font.system(size: 15, weight: .medium)
        public static let size15Semibold          = Font.system(size: 15, weight: .semibold)
        public static let size15MediumMonospaced  = Font.system(size: 15, weight: .medium, design: .monospaced)
        public static let size16                  = Font.system(size: 16)
        public static let size16Semibold          = Font.system(size: 16, weight: .semibold)
        public static let size17                  = Font.system(size: 17)
        public static let size17Semibold          = Font.system(size: 17, weight: .semibold)
        public static let size18                  = Font.system(size: 18)
        public static let size18Medium            = Font.system(size: 18, weight: .medium)
        public static let size18Semibold          = Font.system(size: 18, weight: .semibold)
        public static let size20                  = Font.system(size: 20)
        public static let size20Semibold          = Font.system(size: 20, weight: .semibold)
        public static let size20Monospaced        = Font.system(size: 20, design: .monospaced)
        public static let size22                  = Font.system(size: 22)
        public static let size22Semibold          = Font.system(size: 22, weight: .semibold)
        public static let size22SemiboldRounded   = Font.system(size: 22, weight: .semibold, design: .rounded)

        // --- Display (24+) ---
        public static let size24Bold              = Font.system(size: 24, weight: .bold)
        public static let size28                  = Font.system(size: 28)
        public static let size30Bold              = Font.system(size: 30, weight: .bold)
        public static let size32Semibold          = Font.system(size: 32, weight: .semibold)
        public static let size32MediumMonospaced  = Font.system(size: 32, weight: .medium, design: .monospaced)
        public static let size34SemiboldRounded   = Font.system(size: 34, weight: .semibold, design: .rounded)
        public static let size34SemiboldMonospaced = Font.system(size: 34, weight: .semibold, design: .monospaced)
        public static let size36Bold              = Font.system(size: 36, weight: .bold)
        public static let size36Light             = Font.system(size: 36, weight: .light)
        public static let size38Semibold          = Font.system(size: 38, weight: .semibold)
        public static let size38Heavy             = Font.system(size: 38, weight: .heavy)
        public static let size40                  = Font.system(size: 40)
        public static let size40Bold              = Font.system(size: 40, weight: .bold)
        public static let size44Medium            = Font.system(size: 44, weight: .medium)
        public static let size44Bold              = Font.system(size: 44, weight: .bold)
        public static let size48                  = Font.system(size: 48)
        public static let size48MediumMonospaced  = Font.system(size: 48, weight: .medium, design: .monospaced)
        public static let size56Light             = Font.system(size: 56, weight: .light)

        // MARK: - Runtime-Sized Helper
        //
        // Use ONLY when the pixel size genuinely depends on a runtime value
        // (e.g. vector icon glyph scaling with a parent size parameter).
        // Static design constants MUST use the named tokens above so the
        // typography scale stays auditable from a single file.
        public static func dynamic(size: CGFloat, weight: Font.Weight = .regular) -> Font {
            Font.system(size: size, weight: weight)
        }
    }
}
