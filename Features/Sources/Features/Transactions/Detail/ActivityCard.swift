import Common
import Domain
import SwiftUI

struct ActivityCard: View {
    let transaction: Domain.Transaction

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("transaction_detail_activity")
                .font(Font.Design.size10MediumMonospaced)
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(Color.Design.textSecondary)

            row(icon: transaction.aiSuggested ? "sparkles" : "circle.fill",
                tint: transaction.aiSuggested ? Color.Design.accentOrange : Color.Design.textSecondary,
                key: transaction.aiSuggested ? "transaction_detail_activity_ai" : "transaction_detail_activity_manual",
                date: transaction.createdAt)

            if transaction.updatedAt > transaction.createdAt.addingTimeInterval(1) {
                row(icon: "pencil.circle",
                    tint: Color.Design.textSecondary,
                    key: "transaction_detail_activity_updated",
                    date: transaction.updatedAt)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(Glass.clear.tint(Color.Design.surface), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func row(icon: String, tint: Color, key: LocalizedStringKey, date: Date) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(Font.Design.size12Medium)
                .foregroundStyle(tint)
                .frame(width: 16)
            Text(key)
                .font(Font.Design.size12)
                .foregroundStyle(Color.Design.textPrimary)
            Spacer(minLength: 0)
            Text(date, style: .relative)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Color.Design.textSecondary)
        }
    }
}
