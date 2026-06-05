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

public extension AccountType {
    var new: Account {
        Account(
            id: id,
            name: displayLabel,
            type: self,
            icon: defaultIcon,
            color: defaultColor
        )
    }

    var id: String {
        switch self {
        case .cash:       "com.drake.cash.accountType.id"
        case .bank:       "com.drake.bank.accountType.id"
        case .creditCard: "com.drake.creditCard.accountType.id"
        case .eWallet:    "com.drake.eWallet.accountType.id"
        }
    }

    /// Default SF Symbol name for this account type.
    var defaultIcon: String {
        switch self {
        case .cash:       "banknote"
        case .bank:       "building.columns"
        case .creditCard: "creditcard"
        case .eWallet:    "wallet.bifold"
        }
    }

    /// Default brand color hex (iOS system palette) for this account type.
    var defaultColor: String {
        switch self {
        case .cash:       "#8E8E93"
        case .bank:       "#0A84FF"
        case .creditCard: "#FF2D55"
        case .eWallet:    "#5E5CE6"
        }
    }

    /// A user-facing display label for this account type.
    var displayLabel: String {
        switch self {
        case .cash:       String(localized: "account_type_cash", bundle: .main)
        case .bank:       String(localized: "account_type_bank", bundle: .main)
        case .creditCard: String(localized: "account_type_credit_card", bundle: .main)
        case .eWallet:    String(localized: "account_type_e_wallet", bundle: .main)
        }
    }
}

public struct CustomAccountDraft: Equatable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var type: AccountType
    public var color: String

    public init(id: UUID = UUID(), name: String, type: AccountType, color: String) {
        self.id = id
        self.name = name
        self.type = type
        self.color = color
    }
    
    public var new: Account {
        Account(
            id: id.uuidString,
            name: name,
            type: type,
            icon: type.defaultIcon,
            color: color
        )
    }
}

