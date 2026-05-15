// Features/Sources/Common/Components/StatPill.swift
import SwiftUI

public struct StatPill: View {
    public let label: LocalizedStringKey
    public let value: String
    public let valueColor: Color

    public init(label: LocalizedStringKey, value: String, valueColor: Color = .primary) {
        self.label = label
        self.value = value
        self.valueColor = valueColor
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .textCase(.uppercase)
                .tracking(1)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 16, weight: .semibold).monospacedDigit())
                .foregroundStyle(valueColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.ultraThinMaterial))
    }
}

#Preview {
    HStack(spacing: 10) {
        StatPill(label: "stat_today", value: "NT$ 320")
        StatPill(label: "stat_week", value: "NT$ 2,100", valueColor: Color.Design.expenseRed)
        StatPill(label: "stat_saved", value: "28%", valueColor: Color.Design.incomeGreen)
    }
    .padding()
}
