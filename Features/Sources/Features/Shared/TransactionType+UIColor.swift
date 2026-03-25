import Common
import Domain
import SwiftUI

/// Shared SwiftUI color mapping for TransactionType.
/// Centralises display color logic used across Features screens.
extension TransactionType {
    /// The canonical tint color for this transaction type in list rows and badges.
    var uiColor: Color {
        switch self {
        case .expense:  Color.Design.expenseRed
        case .income:   Color.Design.incomeGreen
        case .transfer: Color.Design.textSecondary
        }
    }

    /// The color used for the large amount text in transaction detail screens.
    /// Transfer uses textPrimary so the prominent amount is clearly readable.
    var amountDisplayColor: Color {
        switch self {
        case .expense:  Color.Design.expenseRed
        case .income:   Color.Design.incomeGreen
        case .transfer: Color.Design.textPrimary
        }
    }
}
