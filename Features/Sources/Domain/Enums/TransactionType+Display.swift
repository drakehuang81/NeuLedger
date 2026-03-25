import Foundation

public extension TransactionType {
    /// Localized display name for UI labels.
    var displayName: String {
        switch self {
        case .expense:  String(localized: "common_expense")
        case .income:   String(localized: "common_income")
        case .transfer: String(localized: "common_transfer")
        }
    }

    /// SF Symbol system image name for this transaction type.
    var systemImageName: String {
        switch self {
        case .expense:  "arrow.up.circle.fill"
        case .income:   "arrow.down.circle.fill"
        case .transfer: "arrow.left.arrow.right.circle.fill"
        }
    }
}
