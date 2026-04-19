import Common
import Domain
import SwiftUI

public struct BudgetRow: View {
    let budget: Budget
    let onToggle: () -> Void

    public init(budget: Budget, onToggle: @escaping () -> Void) {
        self.budget = budget
        self.onToggle = onToggle
    }

    public var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: "banknote")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(budget.isActive ? Color.Design.incomeGreen : Color.Design.textTertiary)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill((budget.isActive ? Color.Design.incomeGreen : Color.Design.textTertiary).opacity(0.15))
                )

            // Name & period
            VStack(alignment: .leading, spacing: 2) {
                Text(budget.name)
                    .font(Font.Design.body)
                    .foregroundStyle(Color.Design.textPrimary)
                Text(periodDisplayName(budget.period))
                    .font(Font.Design.caption)
                    .foregroundStyle(Color.Design.textSecondary)
            }

            Spacer()

            // Amount
            Text(budget.amount.twdFormatted)
                .font(Font.Design.amount)
                .monospacedDigit()
                .foregroundStyle(Color.Design.textPrimary)

            // Active toggle
            Toggle("", isOn: Binding(
                get: { budget.isActive },
                set: { _ in onToggle() }
            ))
            .labelsHidden()
            .tint(Color.Design.incomeGreen)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private func periodDisplayName(_ period: BudgetPeriod) -> String {
        switch period {
        case .weekly: return String(localized: "budget_period_weekly")
        case .monthly: return String(localized: "budget_period_monthly")
        case .yearly: return String(localized: "budget_period_yearly")
        }
    }
}
