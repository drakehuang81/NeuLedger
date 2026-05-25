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

        // MARK: - Fixed Pixel Scale
        //
        // Absolute-pixel sizes for chrome: tags, pills, badges, metric
        // labels, row meta, navigation strips — anywhere the design
        // specifies an exact px size that should NOT scale with Dynamic
        // Type. Covers the top combinations observed across the codebase;
        // extend as new shared sizes emerge (≥ 5 uses guideline).
        public static let size9                   = Font.system(size: 9)
        public static let size9Medium             = Font.system(size: 9, weight: .medium)
        public static let size10                  = Font.system(size: 10)
        public static let size10Medium            = Font.system(size: 10, weight: .medium)
        public static let size10MediumMonospaced  = Font.system(size: 10, weight: .medium, design: .monospaced)
        public static let size11                  = Font.system(size: 11)
        public static let size11Medium            = Font.system(size: 11, weight: .medium)
        public static let size11Semibold          = Font.system(size: 11, weight: .semibold)
        public static let size11Monospaced        = Font.system(size: 11, design: .monospaced)
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
        public static let size15                  = Font.system(size: 15)
        public static let size15Medium            = Font.system(size: 15, weight: .medium)
        public static let size15Semibold          = Font.system(size: 15, weight: .semibold)
        public static let size16                  = Font.system(size: 16)
        public static let size16Semibold          = Font.system(size: 16, weight: .semibold)
        public static let size17Semibold          = Font.system(size: 17, weight: .semibold)
        public static let size18Medium            = Font.system(size: 18, weight: .medium)
        public static let size18Semibold          = Font.system(size: 18, weight: .semibold)
        public static let size20                  = Font.system(size: 20)
        public static let size20Semibold          = Font.system(size: 20, weight: .semibold)
        public static let size22Semibold          = Font.system(size: 22, weight: .semibold)
    }
}
