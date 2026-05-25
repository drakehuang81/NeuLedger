import Domain
import SwiftUI

/// A small chip showing an account's icon, name, and type caption.
///
/// Used inside DetailFieldsCard rows for Account / From / To.
public struct AccountChip: View {
    private let account: Account
    private let dense: Bool

    public init(account: Account, dense: Bool = false) {
        self.account = account
        self.dense = dense
    }

    public var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(swatch.opacity(0.15))
                Image(systemName: account.icon.isEmpty ? "wallet.pass" : account.icon)
                    .font(.system(size: dense ? 12 : 14, weight: .medium))
                    .foregroundStyle(swatch)
                    .symbolRenderingMode(.hierarchical)
            }
            .frame(width: dense ? 22 : 26, height: dense ? 22 : 26)

            VStack(alignment: .leading, spacing: 1) {
                Text(account.name)
                    .font(Font.Design.size14Medium)
                    .foregroundStyle(Color.Design.textPrimary)
                Text(account.type.displayKey)
                    .font(.system(size: 9, weight: .regular, design: .monospaced))
                    .tracking(1)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.Design.textSecondary)
            }
        }
    }

    private var swatch: Color {
        account.color.isEmpty ? Color.Design.accentOrange : Color.Design.fromHex(account.color)
    }
}

private extension AccountType {
    /// Returns a LocalizedStringKey for this account type's caption.
    var displayKey: LocalizedStringKey {
        switch self {
        case .cash: return "account_type_cash"
        case .bank: return "account_type_bank"
        case .creditCard: return "account_type_credit_card"
        case .eWallet: return "account_type_e_wallet"
        }
    }
}
