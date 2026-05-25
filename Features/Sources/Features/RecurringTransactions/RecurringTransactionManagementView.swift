import Common
import SwiftUI
import ComposableArchitecture
import Domain

public struct RecurringTransactionManagementView: View {
    @Bindable var store: StoreOf<RecurringTransactionManagementFeature>

    public init(store: StoreOf<RecurringTransactionManagementFeature>) {
        self.store = store
    }

    public var body: some View {
        ZStack {
            WarmGradientBackground(variant: .top)
                .ignoresSafeArea()

            Group {
                if store.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if store.items.isEmpty {
                    emptyState
                } else {
                    populatedList
                }
            }
        }
        .navigationTitle(String(localized: "recurring_transaction_section_title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    store.send(.addButtonTapped)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .semibold))
                }
            }
        }
        .task { await store.send(.task).finish() }
        .sheet(item: $store.scope(state: \.form, action: \.form)) { formStore in
            NavigationStack {
                RecurringTransactionFormView(store: formStore)
            }
        }
        .alert($store.scope(state: \.alert, action: \.alert))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ScrollView {
            VStack(spacing: 0) {
                VStack(spacing: 22) {
                    // Hero disc
                    ZStack {
                        Circle()
                            .fill(Color.Design.brandAccent.opacity(0.12))
                            .overlay {
                                Circle()
                                    .strokeBorder(Color.Design.brandAccent.opacity(0.22), lineWidth: 0.5)
                            }
                            .frame(width: 96, height: 96)

                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 40, weight: .regular))
                            .foregroundStyle(Color.Design.brandAccent)
                    }
                    .shadow(color: Color.Design.brandAccent.opacity(0.16), radius: 30)

                    VStack(spacing: 8) {
                        Text(String(localized: "recurring_transaction_empty_title"))
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.Design.textPrimary)
                            .multilineTextAlignment(.center)
                            .tracking(-0.4)

                        Text(String(localized: "recurring_transaction_empty_desc"))
                            .font(.system(size: 13.5))
                            .foregroundStyle(Color.Design.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                            .frame(maxWidth: 280)
                    }

                    Button {
                        store.send(.addButtonTapped)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.system(size: 15, weight: .semibold))
                            Text(String(localized: "recurring_transaction_add_button"))
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 13)
                        .background(Color.Design.brandAccent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: Color.Design.brandAccent.opacity(0.35), radius: 10, y: 4)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 48)
                .padding(.horizontal, 20)

                // TODO: Smart suggestions (常見項目 quick-add) — skipped; requires reducer support for prefilled templates
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 120)
        }
    }

    // MARK: - Populated List

    private var populatedList: some View {
        ScrollView {
            VStack(spacing: 18) {
                summaryCard

                let activeItems = store.items.filter { $0.isActive }
                    .sorted { $0.nextDueDate < $1.nextDueDate }
                let pausedItems = store.items.filter { !$0.isActive }

                // Active section
                if !activeItems.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(
                                String(
                                    format: String(localized: "recurring_section_active_format"),
                                    activeItems.count
                                )
                            )
                            .font(.system(size: 11, weight: .medium).monospacedDigit())
                            .textCase(.uppercase)
                            .tracking(1.2)
                            .foregroundStyle(Color.Design.textSecondary)

                            Spacer()

                            Text(String(localized: "recurring_sort_hint"))
                                .font(.system(size: 11, weight: .medium).monospacedDigit())
                                .tracking(0.5)
                                .foregroundStyle(Color.Design.textSecondary)
                        }
                        .padding(.horizontal, 6)

                        GlassContainer(cornerRadius: 18, padding: 0) {
                            VStack(spacing: 0) {
                                ForEach(Array(activeItems.enumerated()), id: \.element.id) { index, item in
                                    recurringRow(item)
                                    if index < activeItems.count - 1 {
                                        Divider()
                                            .padding(.leading, 64)
                                    }
                                }
                            }
                        }
                    }
                }

                // Paused section
                if !pausedItems.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(
                            String(
                                format: String(localized: "recurring_section_paused_format"),
                                pausedItems.count
                            )
                        )
                        .font(.system(size: 11, weight: .medium).monospacedDigit())
                        .textCase(.uppercase)
                        .tracking(1.2)
                        .foregroundStyle(Color.Design.textSecondary)
                        .padding(.horizontal, 6)

                        GlassContainer(cornerRadius: 18, padding: 0) {
                            VStack(spacing: 0) {
                                ForEach(Array(pausedItems.enumerated()), id: \.element.id) { index, item in
                                    recurringRow(item)
                                        .opacity(0.62)
                                    if index < pausedItems.count - 1 {
                                        Divider()
                                            .padding(.leading, 64)
                                    }
                                }
                            }
                        }
                    }
                }

                // Footer hint
                Text(String(localized: "recurring_list_hint"))
                    .font(.system(size: 11))
                    .foregroundStyle(Color.Design.textSecondary)
                    .padding(.horizontal, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineSpacing(3)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 120)
        }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        let activeMonthly = store.items.filter { $0.isActive && $0.frequency == .monthly }
        let monthlyIn = activeMonthly
            .filter { $0.type == .income }
            .reduce(Decimal.zero) { $0 + $1.amount }
        let monthlyOut = activeMonthly
            .filter { $0.type == .expense }
            .reduce(Decimal.zero) { $0 + $1.amount }
        let net = monthlyIn - monthlyOut
        let activeCount = store.items.filter { $0.isActive }.count
        let totalCount = store.items.count

        return GlassContainer(cornerRadius: 20, padding: 18) {
            VStack(alignment: .leading, spacing: 0) {
                // Eyebrow
                HStack(spacing: 6) {
                    Image(systemName: "sparkle")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.Design.brandAccent)
                    Text(String(localized: "recurring_summary_eyebrow"))
                        .font(.system(size: 11, weight: .medium).monospacedDigit())
                        .textCase(.uppercase)
                        .tracking(1.2)
                        .foregroundStyle(Color.Design.textSecondary)
                }

                // Net amount
                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text(String(localized: "recurring_summary_net_label"))
                        .font(.system(size: 12, weight: .medium).monospacedDigit())
                        .foregroundStyle(Color.Design.textSecondary)
                    Text(netAmountText(net))
                        .font(.system(size: 34, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundStyle(Color.Design.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .tracking(-1)
                }
                .padding(.top, 8)

                // Stats row
                HStack(spacing: 14) {
                    // Income
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.left")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.Design.incomeGreen)
                            Text(String(localized: "recurring_summary_in_label"))
                                .font(.system(size: 10, weight: .medium).monospacedDigit())
                                .textCase(.uppercase)
                                .tracking(0.8)
                                .foregroundStyle(Color.Design.textSecondary)
                        }
                        Text("+\(monthlyIn.twdFormatted)")
                            .font(.system(size: 15, weight: .semibold).monospacedDigit())
                            .foregroundStyle(Color.Design.incomeGreen)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Rectangle()
                        .fill(Color.Design.textPrimary.opacity(0.06))
                        .frame(width: 0.5)

                    // Expense
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.Design.textSecondary)
                            Text(String(localized: "recurring_summary_out_label"))
                                .font(.system(size: 10, weight: .medium).monospacedDigit())
                                .textCase(.uppercase)
                                .tracking(0.8)
                                .foregroundStyle(Color.Design.textSecondary)
                        }
                        Text("−\(monthlyOut.twdFormatted)")
                            .font(.system(size: 15, weight: .semibold).monospacedDigit())
                            .foregroundStyle(Color.Design.textPrimary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Rectangle()
                        .fill(Color.Design.textPrimary.opacity(0.06))
                        .frame(width: 0.5)

                    // Items count
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "recurring_summary_items_label"))
                            .font(.system(size: 10, weight: .medium).monospacedDigit())
                            .textCase(.uppercase)
                            .tracking(0.8)
                            .foregroundStyle(Color.Design.textSecondary)
                        HStack(alignment: .lastTextBaseline, spacing: 2) {
                            Text("\(activeCount)")
                                .font(.system(size: 15, weight: .semibold).monospacedDigit())
                                .foregroundStyle(Color.Design.textPrimary)
                            Text("/ \(totalCount)")
                                .font(.system(size: 10, weight: .medium).monospacedDigit())
                                .foregroundStyle(Color.Design.textSecondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.top, 14)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color.Design.textPrimary.opacity(0.06))
                        .frame(height: 0.5)
                }
            }
        }
    }

    private func netAmountText(_ net: Decimal) -> String {
        let prefix = net >= 0 ? "+" : "−"
        let abs = net < 0 ? -net : net
        return "\(prefix)\(abs.twdFormatted)"
    }

    // MARK: - Row

    private func recurringRow(_ item: RecurringTransaction) -> some View {
        Button {
            store.send(.itemTapped(item))
        } label: {
            HStack(spacing: 12) {
                // Icon block
                let freqColor = frequencyColor(item.frequency)
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(freqColor.opacity(0.10))
                    .overlay {
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .strokeBorder(freqColor.opacity(0.20), lineWidth: 0.5)
                    }
                    .overlay {
                        Image(systemName: item.type == .income ? "arrow.down.left.circle" : "arrow.up.right.circle")
                            .font(.system(size: 18, weight: .medium))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(freqColor)
                    }
                    .frame(width: 38, height: 38)

                // Middle
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(item.note ?? "")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.Design.textPrimary)
                            .lineLimit(1)

                        freqPill(item.frequency)
                    }

                    HStack(spacing: 5) {
                        if item.isActive {
                            // TODO: accountName fallback — no accountClient injected here;
                            // showing due date only until account lookup is added via a helper.
                            let dueText = dueDateText(item.nextDueDate)
                            let dueColor = dueDateColor(item.nextDueDate)
                            Text(dueText)
                                .font(.system(size: 11.5).monospacedDigit())
                                .tracking(0.2)
                                .foregroundStyle(dueColor)
                        } else {
                            Text(String(localized: "recurring_paused_inline"))
                                .font(.system(size: 10, weight: .medium).monospacedDigit())
                                .textCase(.uppercase)
                                .tracking(0.5)
                                .foregroundStyle(Color.Design.textSecondary)
                        }
                    }
                }

                Spacer(minLength: 4)

                // Right: amount + toggle
                HStack(spacing: 10) {
                    let isIncome = item.type == .income
                    let prefix = isIncome ? "+" : "−"
                    Text("\(prefix)\(item.amount.twdFormatted)")
                        .font(.system(size: 14, weight: .semibold).monospacedDigit())
                        .foregroundStyle(isIncome ? Color.Design.incomeGreen : Color.Design.textPrimary)
                        .lineLimit(1)

                    Toggle("", isOn: Binding(
                        get: { item.isActive },
                        set: { _ in store.send(.toggleActiveTapped(item)) }
                    ))
                    .labelsHidden()
                    .allowsHitTesting(true)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                store.send(.deleteRequested(item.id))
            } label: {
                Label(String(localized: "common_delete"), systemImage: "trash")
            }
        }
    }

    // MARK: - Helpers

    private func frequencyColor(_ frequency: BudgetPeriod) -> Color {
        switch frequency {
        case .weekly:  return Color.Design.iconBlueAlt
        case .monthly: return Color.Design.brandAccent
        case .yearly:  return Color.Design.aiPurple
        }
    }

    private func freqPill(_ frequency: BudgetPeriod) -> some View {
        let color = frequencyColor(frequency)
        let label: LocalizedStringKey
        switch frequency {
        case .weekly:  label = "recurring_freq_weekly_short"
        case .monthly: label = "recurring_freq_monthly_short"
        case .yearly:  label = "recurring_freq_yearly_short"
        }
        return Text(label)
            .font(.system(size: 10, weight: .semibold).monospacedDigit())
            .textCase(.uppercase)
            .tracking(0.5)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private func dueDateText(_ date: Date) -> String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let target = calendar.startOfDay(for: date)
        let days = calendar.dateComponents([.day], from: today, to: target).day ?? 0

        if days == 0 {
            return String(localized: "recurring_due_today")
        } else {
            let formatted = date.formatted(.dateTime.month().day())
            return String(format: String(localized: "recurring_due_format"), formatted)
        }
    }

    private func dueDateColor(_ date: Date) -> Color {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let target = calendar.startOfDay(for: date)
        let days = calendar.dateComponents([.day], from: today, to: target).day ?? 0
        return days <= 3 ? Color.Design.brandAccent : Color.Design.textSecondary
    }
}

// MARK: - Previews

#Preview("Populated") {
    NavigationStack {
        RecurringTransactionManagementView(
            store: Store(
                initialState: RecurringTransactionManagementFeature.State(
                    items: [
                        RecurringTransaction(
                            id: UUID(),
                            amount: 68000,
                            note: "薪水",
                            categoryId: nil,
                            accountId: UUID(),
                            toAccountId: nil,
                            type: .income,
                            tags: [],
                            frequency: .monthly,
                            nextDueDate: Calendar.current.date(byAdding: .day, value: 10, to: Date())!,
                            isActive: true,
                            createdAt: Date()
                        ),
                        RecurringTransaction(
                            id: UUID(),
                            amount: 22000,
                            note: "房租",
                            categoryId: nil,
                            accountId: UUID(),
                            toAccountId: nil,
                            type: .expense,
                            tags: [],
                            frequency: .monthly,
                            nextDueDate: Calendar.current.date(byAdding: .day, value: 21, to: Date())!,
                            isActive: true,
                            createdAt: Date()
                        ),
                        RecurringTransaction(
                            id: UUID(),
                            amount: 390,
                            note: "Netflix",
                            categoryId: nil,
                            accountId: UUID(),
                            toAccountId: nil,
                            type: .expense,
                            tags: [],
                            frequency: .monthly,
                            nextDueDate: Date(),
                            isActive: true,
                            createdAt: Date()
                        ),
                        RecurringTransaction(
                            id: UUID(),
                            amount: 18400,
                            note: "汽車保險",
                            categoryId: nil,
                            accountId: UUID(),
                            toAccountId: nil,
                            type: .expense,
                            tags: [],
                            frequency: .yearly,
                            nextDueDate: Calendar.current.date(byAdding: .day, value: 172, to: Date())!,
                            isActive: true,
                            createdAt: Date()
                        ),
                        RecurringTransaction(
                            id: UUID(),
                            amount: 168,
                            note: "蘋果日報訂閱",
                            categoryId: nil,
                            accountId: UUID(),
                            toAccountId: nil,
                            type: .expense,
                            tags: [],
                            frequency: .monthly,
                            nextDueDate: Calendar.current.date(byAdding: .day, value: -5, to: Date())!,
                            isActive: false,
                            createdAt: Date()
                        )
                    ]
                )
            ) {
                RecurringTransactionManagementFeature()
            }
        )
    }
}

#Preview("Empty") {
    NavigationStack {
        RecurringTransactionManagementView(
            store: Store(
                initialState: RecurringTransactionManagementFeature.State(items: [])
            ) {
                RecurringTransactionManagementFeature()
            }
        )
    }
}
