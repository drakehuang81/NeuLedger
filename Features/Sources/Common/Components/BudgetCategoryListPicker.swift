import Domain
import SwiftUI

/// A radio-style picker for choosing a Budget category (or "All expenses").
///
/// Layout: each row has a 32pt color-tinted SF Symbol circle, the
/// category name, and a trailing checkmark when selected. The first row
/// is a sentinel "All expenses" with `id == nil`, rendered with the
/// `asterisk` SF Symbol.
public struct BudgetCategoryListPicker: View {
    private let categories: [Domain.Category]
    private let selectedId: Domain.Category.ID?
    private let onSelect: (Domain.Category.ID?) -> Void

    public init(
        categories: [Domain.Category],
        selectedId: Domain.Category.ID?,
        onSelect: @escaping (Domain.Category.ID?) -> Void
    ) {
        self.categories = categories
        self.selectedId = selectedId
        self.onSelect = onSelect
    }

    public var body: some View {
        VStack(spacing: 0) {
            row(
                symbol: "asterisk",
                color: Color.Design.accentOrange,
                title: Text("budget_form_all_expenses"),
                isAll: true,
                isSelected: selectedId == nil,
                action: { onSelect(nil) }
            )

            ForEach(Array(categories.enumerated()), id: \.element.id) { _, cat in
                Divider()
                    .padding(.leading, 60)

                row(
                    symbol: cat.icon,
                    color: Color.Design.fromHex(cat.color),
                    title: Text(cat.localizedName),
                    isAll: false,
                    isSelected: selectedId == cat.id,
                    action: { onSelect(cat.id) }
                )
            }
        }
    }

    private func row(
        symbol: String,
        color: Color,
        title: Text,
        isAll: Bool,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.12))
                    Image(systemName: symbol.isEmpty ? "tag" : symbol)
                        .font(.system(
                            size: isAll ? 14 : 15,
                            weight: isAll ? .bold : .medium
                        ))
                        .foregroundStyle(color)
                        .symbolRenderingMode(.hierarchical)
                }
                .frame(width: 32, height: 32)

                title
                    .font(Font.Design.size16)
                    .foregroundStyle(Color.Design.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(Font.Design.size18Semibold)
                        .foregroundStyle(Color.Design.accentOrange)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(isAll ? "budget_form_category_all" : "budget_form_category_row")
    }
}
