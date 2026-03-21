import Foundation

public extension Decimal {
    /// Formats the amount as TWD currency: "NT$46,200"
    var twdFormatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "NT$"
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter.string(from: self as NSDecimalNumber) ?? "NT$0"
    }
}
