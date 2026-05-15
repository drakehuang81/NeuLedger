// Features/Sources/Common/Components/MiniSparkline.swift
import SwiftUI

public struct MiniSparkline: View {
    public let values: [Decimal]
    public let accentColor: Color
    public let baseColor: Color

    public init(
        values: [Decimal],
        minimumColumns: Int = 1,
        accentColor: Color = Color.Design.brandPrimary,
        baseColor: Color = Color.secondary.opacity(0.3)
    ) {
        if values.count < minimumColumns {
            let padCount = minimumColumns - values.count
            self.values = Array(repeating: .zero, count: padCount) + values
        } else {
            self.values = values
        }
        self.accentColor = accentColor
        self.baseColor = baseColor
    }

    private var maxValue: Decimal {
        max(values.max() ?? 1, 1)
    }

    public var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(values.indices, id: \.self) { i in
                let v = NSDecimalNumber(decimal: values[i]).doubleValue
                let m = NSDecimalNumber(decimal: maxValue).doubleValue
                let h = max(CGFloat(v / m) * 30, 2)
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(i == values.indices.last ? accentColor : baseColor)
                    .frame(width: 5, height: h)
            }
        }
        .frame(height: 30, alignment: .bottom)
    }
}

#Preview {
    VStack {
        MiniSparkline(values: [120, 80, 200, 60, 140, 90, 180])
    }
    .padding()
}
