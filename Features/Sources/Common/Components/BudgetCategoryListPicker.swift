import Domain
import SwiftUI

/// A radio-style picker for choosing a Budget category (or "All expenses").
///
/// Layout: each row has a 32pt color-tinted emoji circle, the category
/// name, and a trailing checkmark when selected. The first row is a
/// sentinel "All expenses ∗" with `id == nil`.
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
                emoji: "∗",
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
                    emoji: cat.icon,
                    color: Color(hex: cat.color),
                    title: Text(cat.name),
                    isAll: false,
                    isSelected: selectedId == cat.id,
                    action: { onSelect(cat.id) }
                )
            }
        }
    }

    private func row(
        emoji: String,
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
                    Text(emoji)
                        .font(.system(
                            size: isAll ? 18 : 16,
                            weight: isAll ? .bold : .regular
                        ))
                        .foregroundStyle(color)
                }
                .frame(width: 32, height: 32)

                title
                    .font(.system(size: 15.5))
                    .foregroundStyle(Color.Design.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 18, weight: .semibold))
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
