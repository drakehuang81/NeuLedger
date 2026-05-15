import SwiftUI

/// A label-value row used inside a Glass details card.
///
/// Layout: 76pt monospaced UPPERCASE label on the left, value content
/// flexible right. Optional bottom divider — pass `showsDivider: false`
/// on the last row.
public struct DetailField<Value: View>: View {
    private let labelKey: LocalizedStringKey
    private let dense: Bool
    private let showsDivider: Bool
    private let value: () -> Value

    public init(
        _ labelKey: LocalizedStringKey,
        dense: Bool = false,
        showsDivider: Bool = true,
        @ViewBuilder value: @escaping () -> Value
    ) {
        self.labelKey = labelKey
        self.dense = dense
        self.showsDivider = showsDivider
        self.value = value
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 14) {
                Text(labelKey)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.Design.textSecondary)
                    .frame(width: 76, alignment: .leading)
                value()
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.Design.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, dense ? 10 : 14)

            if showsDivider {
                Divider()
            }
        }
    }
}
