import Common
import ComposableArchitecture
import Domain
import SwiftUI

public struct FilterView: View {
    @Bindable var store: StoreOf<FilterFeature>

    public init(store: StoreOf<FilterFeature>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                WarmGradientBackground(variant: .top)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        typeSection
                        if !store.categories.isEmpty {
                            categorySection
                        }
                        if !store.accounts.isEmpty {
                            accountSection
                        }
                        if !store.tags.isEmpty {
                            tagSection
                        }
                        dateSection
                        resetButton
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 60)
                }
            }
            .navigationTitle(String(localized: "filter_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "filter_clear_all")) {
                        store.send(.clearAllTapped)
                    }
                    .foregroundStyle(Color.Design.expenseRed)
                }
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Text(String(localized: "filter_title"))
                            .font(.system(size: 17, weight: .semibold))
                        if store.activeFilterCount > 0 {
                            Text("\(store.activeFilterCount)")
                                .font(.system(size: 12, weight: .bold).monospacedDigit())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.Design.brandAccent, in: Capsule())
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        store.send(.applyTapped)
                    } label: {
                        Text(String(localized: "filter_apply"))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Color.Design.brandAccent, in: Capsule())
                    }
                }
            }
            .task {
                await store.send(.task).finish()
            }
        }
    }

    // MARK: - Type Section

    private var typeSection: some View {
        filterSection(label: String(localized: "transactions_filter_section_type")) {
            FlowLayout(spacing: 8) {
                ForEach([TransactionType.expense, .income, .transfer], id: \.self) { type in
                    typeChip(type)
                }
            }
        }
    }

    private func typeChip(_ type: TransactionType) -> some View {
        let isActive = store.selectedTypes.contains(type)
        let color: Color = switch type {
        case .expense: Color.Design.expenseRed
        case .income: Color.Design.incomeGreen
        case .transfer: Color.Design.transferPurple
        }
        return Button {
            store.send(.typeToggled(type))
        } label: {
            HStack(spacing: 5) {
                Image(systemName: type.systemImageName)
                    .font(.system(size: 13, weight: .semibold))
                Text(type.displayName)
                    .font(.system(size: 13, weight: .medium))
                if isActive {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                }
            }
            .foregroundStyle(isActive ? color : Color.Design.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background {
                Capsule()
                    .fill(isActive ? color.opacity(0.13) : Color.Design.textPrimary.opacity(0.05))
                    .overlay {
                        Capsule()
                            .strokeBorder(
                                isActive ? color : Color.clear,
                                lineWidth: 1
                            )
                    }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Category Section

    private var categorySection: some View {
        filterSection(label: String(localized: "transactions_filter_section_category")) {
            FlowLayout(spacing: 8) {
                ForEach(store.categories) { category in
                    categoryChip(category)
                }
            }
        }
    }

    private func categoryChip(_ category: Domain.Category) -> some View {
        let isActive = store.selectedCategoryIds.contains(category.id)
        let color = Color.Design.fromHex(category.color)
        return Button {
            store.send(.categoryToggled(category.id))
        } label: {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(color)
                    .frame(width: 16, height: 16)
                    .overlay {
                        Image(systemName: category.icon)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                Text(category.localizedName)
                    .font(.system(size: 13, weight: .medium))
                if isActive {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                }
            }
            .foregroundStyle(isActive ? color : Color.Design.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background {
                Capsule()
                    .fill(isActive ? color.opacity(0.13) : Color.Design.textPrimary.opacity(0.05))
                    .overlay {
                        Capsule()
                            .strokeBorder(
                                isActive ? color : Color.clear,
                                lineWidth: 1
                            )
                    }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Account Section

    private var accountSection: some View {
        filterSection(label: String(localized: "transactions_filter_section_account")) {
            FlowLayout(spacing: 8) {
                ForEach(store.accounts) { account in
                    accountChip(account)
                }
            }
        }
    }

    private func accountChip(_ account: Account) -> some View {
        let isActive = store.selectedAccountIds.contains(account.id)
        let color = Color.Design.fromHex(account.color)
        return Button {
            store.send(.accountToggled(account.id))
        } label: {
            HStack(spacing: 6) {
                Image(systemName: account.icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(account.name)
                    .font(.system(size: 13, weight: .medium))
                if isActive {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                }
            }
            .foregroundStyle(isActive ? color : Color.Design.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background {
                Capsule()
                    .fill(isActive ? color.opacity(0.13) : Color.Design.textPrimary.opacity(0.05))
                    .overlay {
                        Capsule()
                            .strokeBorder(
                                isActive ? color : Color.clear,
                                lineWidth: 1
                            )
                    }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tag Section

    private var tagSection: some View {
        filterSection(label: String(localized: "transactions_filter_section_tag")) {
            FlowLayout(spacing: 8) {
                ForEach(store.tags) { tag in
                    tagChip(tag)
                }
            }
        }
    }

    private func tagChip(_ tag: Tag) -> some View {
        let isActive = store.selectedTagIds.contains(tag.id)
        let color = Color.Design.fromHex(tag.color ?? "#FF9500")
        return Button {
            store.send(.tagToggled(tag.id))
        } label: {
            HStack(spacing: 5) {
                Text("#\(tag.name)")
                    .font(.system(size: 13, weight: .medium))
                if isActive {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                }
            }
            .foregroundStyle(isActive ? color : Color.Design.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background {
                Capsule()
                    .fill(isActive ? color.opacity(0.13) : Color.Design.textPrimary.opacity(0.05))
                    .overlay {
                        Capsule()
                            .strokeBorder(
                                isActive ? color : Color.clear,
                                lineWidth: 1
                            )
                    }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Date Section

    private var dateSection: some View {
        let hasDates = store.startDate != nil || store.endDate != nil
        return filterSection(
            label: String(localized: "transactions_filter_section_date"),
            action: hasDates
                ? AnyView(
                    Button(String(localized: "transactions_filter_date_clear")) {
                        store.send(.startDateChanged(nil))
                        store.send(.endDateChanged(nil))
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.Design.expenseRed)
                )
                : nil
        ) {
            VStack(spacing: 10) {
                GlassContainer(cornerRadius: 16, padding: 0, isInteractive: false) {
                    VStack(spacing: 0) {
                        DatePicker(
                            String(localized: "transactions_filter_date_start"),
                            selection: Binding(
                                get: { store.startDate ?? Date() },
                                set: { store.send(.startDateChanged($0)) }
                            ),
                            displayedComponents: .date
                        )
                        .font(Font.Design.body)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)

                        Divider()
                            .padding(.leading, 16)

                        DatePicker(
                            String(localized: "transactions_filter_date_end"),
                            selection: Binding(
                                get: { store.endDate ?? Date() },
                                set: { store.send(.endDateChanged($0)) }
                            ),
                            displayedComponents: .date
                        )
                        .font(Font.Design.body)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }

                // Quick date range chips
                HStack(spacing: 6) {
                    quickDateChip(
                        label: String(localized: "transactions_filter_quick_this_week"),
                        range: .thisWeek
                    )
                    quickDateChip(
                        label: String(localized: "transactions_filter_quick_this_month"),
                        range: .thisMonth
                    )
                    quickDateChip(
                        label: String(localized: "transactions_filter_quick_last_month"),
                        range: .lastMonth
                    )
                    quickDateChip(
                        label: String(localized: "transactions_filter_quick_this_year"),
                        range: .thisYear
                    )
                }
            }
        }
    }

    private func quickDateChip(label: String, range: QuickDateRange) -> some View {
        let (start, end) = range.dates
        let isActive = store.startDate == start && store.endDate == end
        return Button {
            store.send(.startDateChanged(start))
            store.send(.endDateChanged(end))
        } label: {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isActive ? Color.Design.brandAccent : Color.Design.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background {
                    Capsule()
                        .fill(isActive
                            ? Color.Design.brandAccent.opacity(0.12)
                            : Color.Design.textPrimary.opacity(0.05))
                        .overlay {
                            Capsule()
                                .strokeBorder(
                                    isActive ? Color.Design.brandAccent : Color.clear,
                                    lineWidth: 1
                                )
                        }
                }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Reset Button

    private var resetButton: some View {
        Button {
            store.send(.clearAllTapped)
        } label: {
            Text(String(localized: "transactions_filter_reset"))
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.Design.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.Design.textPrimary.opacity(0.04))
                }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Section Helper

    @ViewBuilder
    private func filterSection<Content: View>(
        label: String,
        action: AnyView? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .textCase(.uppercase)
                    .tracking(1.2)
                    .foregroundStyle(Color.Design.textSecondary)
                    .padding(.horizontal, 6)
                Spacer()
                action
                    .padding(.horizontal, 6)
            }
            content()
        }
    }
}

// MARK: - FlowLayout

/// A simple wrapping HStack-style layout for chip rows.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var height: CGFloat = 0
        var x: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                height += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        height += rowHeight
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Quick Date Range

private enum QuickDateRange {
    case thisWeek, thisMonth, lastMonth, thisYear

    var dates: (Date, Date) {
        let cal = Calendar.current
        let now = Date()
        switch self {
        case .thisWeek:
            let start = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
            let end = cal.date(byAdding: .day, value: 6, to: start)!
            return (start, end)
        case .thisMonth:
            let start = cal.date(from: cal.dateComponents([.year, .month], from: now))!
            let end = cal.date(byAdding: DateComponents(month: 1, day: -1), to: start)!
            return (start, end)
        case .lastMonth:
            let thisMonthStart = cal.date(from: cal.dateComponents([.year, .month], from: now))!
            let start = cal.date(byAdding: .month, value: -1, to: thisMonthStart)!
            let end = cal.date(byAdding: .day, value: -1, to: thisMonthStart)!
            return (start, end)
        case .thisYear:
            let start = cal.date(from: cal.dateComponents([.year], from: now))!
            let end = cal.date(byAdding: DateComponents(year: 1, day: -1), to: start)!
            return (start, end)
        }
    }
}
