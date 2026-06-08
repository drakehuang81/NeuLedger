import Foundation

public extension String {
    /// 將此字串解析成金額的 Decimal（會自動清除千分位符號、逗號與空白）
    var parsedAmountDecimal: Decimal? {
        let trimmed = self.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.generatesDecimalNumbers = true
        if let number = formatter.number(from: trimmed) {
            return number.decimalValue
        }

        let separators = [
            formatter.groupingSeparator,
            Locale.current.groupingSeparator,
            ",",
            "，",
            " "
        ]
        let normalized = separators
            .compactMap { $0 }
            .reduce(trimmed) { partial, separator in
                partial.replacingOccurrences(of: separator, with: "")
            }

        return Decimal(string: normalized)
    }
}
