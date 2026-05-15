import Common
import Domain
import SwiftUI

/// Placeholder Hero — final implementation lands in Task 6.
struct TxHero: View {
    let transaction: Domain.Transaction
    let categoryName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(transaction.amount.twdFormatted)
                .font(Font.Design.largeTitle.weight(.bold).monospacedDigit())
                .foregroundStyle(transaction.type.amountDisplayColor)
            if let name = categoryName ?? transaction.note {
                Text(name)
                    .font(Font.Design.headline.weight(.semibold))
                    .foregroundStyle(Color.Design.textPrimary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
