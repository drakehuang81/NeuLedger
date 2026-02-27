import Foundation

/// A type that specifies the financial nature of an account.
///
/// Use `AccountType` to distinguish between different forms of asset holdings,
/// which determines how the system presents the account in the interface and how it processes specific financial logic.
/// For example, a credit card account might require additional handling for billing cycles and payment due dates.
public enum AccountType: String, Codable, CaseIterable, Equatable, Sendable {
    /// An account representing physical fiat currency.
    case cash
    
    /// A checking or savings account held at a financial institution.
    case bank
    
    /// A credit card account representing borrowed funds.
    case creditCard
    
    /// A digital wallet account, such as Apple Pay Cash, LINE Pay, or other electronic payment services.
    case eWallet
}
