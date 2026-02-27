import Foundation

/// A type that represents the supported currencies within the ledger system.
///
/// Use `Currency` to standardize how monetary values are displayed, formated, and interacted with.
/// It provides utility properties corresponding to official currency codes and symbols.
public enum Currency: String, Codable, CaseIterable, Equatable, Sendable {
    /// New Taiwan Dollar.
    case TWD
    
    /// The localized symbol used for displaying the currency (e.g., "NT$").
    public var symbol: String {
        switch self {
        case .TWD: "NT$"
        }
    }
    
    /// The standard three-letter ISO currency code (e.g., "TWD").
    public var code: String {
        switch self {
        case .TWD: "TWD"
        }
    }
    
    /// The standard number of decimal places typically used for formatting this currency.
    ///
    /// For instance, TWD usually has `0` decimal places, whereas USD has `2`.
    public var decimalPlaces: Int {
        switch self {
        case .TWD: 0
        }
    }
}
