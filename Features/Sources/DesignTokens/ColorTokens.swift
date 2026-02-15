import SwiftUI
import UIKit

// MARK: - Brand Colors
public extension Color {
    /// Pure Code Design Tokens (No Asset Catalog dependency)
    enum Design {
        /// Income Green: Light #34C759 / Dark #30D158
        /// Usage: Income amounts, positive deltas
        public static var incomeGreen: Color {
            Color(uiColor: UIColor { traitCollection in
                if traitCollection.userInterfaceStyle == .dark {
                    return UIColor(red: 0.188, green: 0.820, blue: 0.345, alpha: 1.0)
                } else {
                    return UIColor(red: 0.204, green: 0.780, blue: 0.349, alpha: 1.0)
                }
            })
        }
        
        /// Expense Red: Light #FF3B30 / Dark #FF453A
        /// Usage: Expense amounts, negative deltas
        public static var expenseRed: Color {
            Color(uiColor: UIColor { traitCollection in
                if traitCollection.userInterfaceStyle == .dark {
                    return UIColor(red: 1.000, green: 0.271, blue: 0.227, alpha: 1.0)
                } else {
                    return UIColor(red: 1.000, green: 0.231, blue: 0.188, alpha: 1.0)
                }
            })
        }
        
        /// Warning Amber: Light #FF9500 / Dark #FF9F0A
        /// Usage: Budget warnings
        public static var warningAmber: Color {
            Color(uiColor: UIColor { traitCollection in
                if traitCollection.userInterfaceStyle == .dark {
                    return UIColor(red: 1.000, green: 0.624, blue: 0.039, alpha: 1.0)
                } else {
                    return UIColor(red: 1.000, green: 0.584, blue: 0.000, alpha: 1.0)
                }
            })
        }
    }
}

// MARK: - Semantic UI Colors
public extension Color.Design {
    /// Main text content (System .primary)
    static var textPrimary: Color { .primary }
    
    /// Supporting text, subtitles (System .secondary)
    static var textSecondary: Color { .secondary }
    
    /// Screen backgrounds (System .systemBackground equivalent)
    static var background: Color { Color(uiColor: .systemBackground) }
    
    /// List / Form backgrounds (System .systemGroupedBackground equivalent)
    static var groupedBackground: Color { Color(uiColor: .systemGroupedBackground) }
    
    /// Elevated card surfaces (System .secondarySystemGroupedBackground equivalent)
    static var cardSurface: Color { Color(uiColor: .secondarySystemGroupedBackground) }
    
    /// Thin divider lines (System .separator equivalent)
    static var separator: Color { Color(uiColor: .separator) }
}
