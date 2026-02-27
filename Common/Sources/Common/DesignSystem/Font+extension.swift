import SwiftUI

public extension Font {
    enum Design {
        public static let largeTitle = Font.largeTitle
        public static let title2 = Font.title2
        public static let headline = Font.headline
        public static let body = Font.body
        public static let callout = Font.callout
        public static let subheadline = Font.subheadline
        public static let caption = Font.caption
        
        /// Monospaced digit body font for financial amounts
        public static let amount = Font.body.monospacedDigit()
    }
}
