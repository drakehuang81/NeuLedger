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
        GlassContainer {
            VStack(alignment: .leading, spacing: 6) {
                Text(label)
                    .font(Font.Design.size10Medium)
                    .textCase(.uppercase)
                    .tracking(1)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(value)
                    .font(Font.Design.size16Semibold.monospacedDigit())
                    .foregroundStyle(valueColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    ProportionalHStack(spacing: 10) {
        StatPill(label: "stat_today", value: "NT$ 320")
        StatPill(label: "stat_week", value: "NT$ 1,234,567", valueColor: Color.Design.expenseRed)
        StatPill(label: "stat_saved", value: "28%", valueColor: Color.Design.incomeGreen)
    }
    .padding()
}
