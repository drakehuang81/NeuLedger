// Features/Sources/Common/Components/MetricBadge.swift
import SwiftUI

public struct MetricBadge: View {
    public let text: String
    public let color: Color

    public init(text: String, color: Color) {
        self.text = text
        self.color = color
    }

    public var body: some View {
        Text(text)
            .font(Font.Design.size11Medium.monospacedDigit())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(color.opacity(0.18)))
            .foregroundStyle(color)
    }
}

#Preview {
    HStack(spacing: 8) {
        MetricBadge(text: "+12%", color: Color.Design.incomeGreen)
        MetricBadge(text: "-NT$ 320", color: Color.Design.expenseRed)
        MetricBadge(text: "42%", color: Color.Design.brandPrimary)
    }
    .padding()
}
