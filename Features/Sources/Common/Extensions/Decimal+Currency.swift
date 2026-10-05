import Foundation
import Domain

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
    /// Compact TWD format for space-constrained UI.
    /// < 10,000 → "NT$9,999"; >= 10,000 → "NT$9.9萬"; >= 100,000,000 → "NT$1.2億"
    var twdCompact: String {
        let value = NSDecimalNumber(decimal: self).doubleValue
        let absValue = abs(value)
        let sign = value < 0 ? "-" : ""
        switch absValue {
        case 100_000_000...:
            return "\(sign)NT$\(String(format: "%.1f", absValue / 100_000_000))億"
        case 10_000...:
            return "\(sign)NT$\(String(format: "%.1f", absValue / 10_000))萬"
        default:
            return twdFormatted
        }
    }

    /// 千分位整數字串、不含貨幣符號："12,500"。
    /// Watch / Complication / 需要把符號另排的卡片用這個。
    var twdDigits: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        let magnitude = self < 0 ? -self : self
        return formatter.string(from: magnitude as NSDecimalNumber) ?? "0"
    }

    /// (符號, 數字) 兩段，供「小字 NT$ + 大字數字」排版。
    /// 負號留在符號上："-NT$" + "1,234"。
    var twdParts: (symbol: String, digits: String) {
        let symbol = Currency.TWD.symbol
        return (self < 0 ? "-" + symbol : symbol, twdDigits)
    }
}
