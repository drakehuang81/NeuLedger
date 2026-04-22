import Common
import Domain
import Foundation
import SwiftUI

/// Shared presentation helpers for `Domain.Transaction` used across Features screens.
///
/// Centralises signed-amount formatting so list rows on Dashboard, Transactions, etc.
/// share a single source of truth for expense/income/transfer sign convention.
extension Domain.Transaction {
    /// The amount with the convention sign for list display:
    /// - expense:  negative (e.g. `-100`)
    /// - income:   positive (e.g. `100`)
    /// - transfer: positive absolute value (no sign)
    var signedAmount: Decimal {
        switch type {
        case .expense:  return -amount
        case .income, .transfer: return amount
        }
    }

    /// The formatted TWD string for `signedAmount`.
    /// Example outputs: `-NT$100`, `NT$100`.
    var signedAmountText: String {
        signedAmount.twdFormatted
    }
}
