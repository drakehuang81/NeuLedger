import Foundation

// NOTE: The localization keys consumed below
// (`budget_form_breakdown_weekly` / `_monthly` / `_yearly`) and the
// `BudgetPeriod.localizedSuffix` keys
// (`budget_period_suffix_weekly` / `_monthly` / `_yearly`) live in TWO
// xcstrings catalogs and must be kept in sync:
//
//   - Features/Sources/Domain/Resources/Localizable.xcstrings  (Bundle.module)
//   - NeuLedger/Resources/Localizable.xcstrings                (Bundle.main)
//
// The Domain bundle exists so DomainTests can resolve these strings
// when running in isolation (the test runner becomes Bundle.main and
// would otherwise miss the app's catalog).

public extension Decimal {

    /// Returns a localized human-readable per-period breakdown of this amount.
    ///
    /// - For `.monthly`, produces "≈ NT$X / 天 · 約 NT$Y / 週" (zh-Hant).
    /// - For `.weekly`, produces "≈ NT$X / 天".
    /// - For `.yearly`, produces "≈ NT$X / 月".
    /// - Returns `nil` when the amount is zero or negative.
    ///
    /// Rounding uses "round half away from zero" (`NSDecimalRoundingMode.plain`)
    /// to the nearest integer.
    func perPeriodBreakdown(_ period: BudgetPeriod) -> String? {
        guard self > 0 else { return nil }
        switch period {
        case .weekly:
            let perDay = Self.rounded(self / 7)
            return String(
                format: String(localized: "budget_form_breakdown_weekly", bundle: .module),
                Self.formatted(perDay)
            )
        case .monthly:
            let perDay  = Self.rounded(self / 30)
            let perWeek = Self.rounded(self / Decimal(string: "4.33")!)
            return String(
                format: String(localized: "budget_form_breakdown_monthly", bundle: .module),
                Self.formatted(perDay),
                Self.formatted(perWeek)
            )
        case .yearly:
            let perMonth = Self.rounded(self / 12)
            return String(
                format: String(localized: "budget_form_breakdown_yearly", bundle: .module),
                Self.formatted(perMonth)
            )
        }
    }

    private static func rounded(_ value: Decimal) -> Decimal {
        var input = value
        var output = Decimal()
        NSDecimalRound(&output, &input, 0, .plain)
        return output
    }

    private static func formatted(_ value: Decimal) -> String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .decimal
        fmt.maximumFractionDigits = 0
        return fmt.string(from: value as NSDecimalNumber) ?? "0"
    }
}
