import Common
import Domain
import SwiftUI

struct DetailFieldsCard: View {
    let transaction: Domain.Transaction
    let account: Account?
    let toAccount: Account?

    var body: some View {
        VStack(spacing: 0) {
            if transaction.type == .transfer {
                if let from = account {
                    DetailField("transaction_detail_from") { AccountChip(account: from) }
                }
                if let to = toAccount {
                    DetailField("transaction_detail_to") { AccountChip(account: to) }
                }
            } else if let account {
                DetailField("transaction_detail_account") { AccountChip(account: account) }
            }

            DetailField("transaction_detail_date") {
                VStack(alignment: .leading, spacing: 2) {
                    Text(transaction.date, format: .dateTime.year().month(.wide).day())
                    Text(transaction.date, format: .dateTime.hour().minute())
                        .font(Font.Design.size11Monospaced)
                        .foregroundStyle(Color.Design.textSecondary)
                }
            }

            if let note = transaction.note, !note.isEmpty {
                DetailField("transaction_detail_note", showsDivider: false) {
                    Text(note)
                        .multilineTextAlignment(.leading)
                }
            }
        }
        .padding(.horizontal, 16)
        .glassEffect(Glass.clear.tint(Color.Design.surface), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
