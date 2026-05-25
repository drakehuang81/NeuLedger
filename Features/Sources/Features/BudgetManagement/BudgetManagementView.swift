import Common
import ComposableArchitecture
import Domain
import SwiftUI

public struct BudgetManagementView: View {
    @Bindable var store: StoreOf<BudgetManagementFeature>

    public init(store: StoreOf<BudgetManagementFeature>) {
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
                } else if store.budgets.isEmpty {
                    emptyState
                } else {
                    budgetList
                }
            }
        }
        .navigationTitle(String(localized: "settings_budget_management"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    store.send(.addButtonTapped)
                } label: {
                    Image(systemName: "plus")
                        .font(Font.Design.size17Semibold)
                }
                .accessibilityLabel(String(localized: "budget_management_add"))
            }
        }
        .task {
            await store.send(.task).finish()
        }
        .sheet(item: $store.scope(state: \.addEdit, action: \.addEdit)) { formStore in
            BudgetFormView(store: formStore)
        }
        .alert($store.scope(state: \.alert, action: \.alert))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        EmptyStateView(
            icon: "banknote",
            title: String(localized: "budget_management_empty_title"),
            description: String(localized: "budget_management_empty_desc"),
            actionTitle: String(localized: "budget_management_add")
        ) {
            store.send(.addButtonTapped)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Budget List

    private var budgetList: some View {
        ScrollView {
            VStack(spacing: 18) {
                summaryHero
                budgetSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 120)
        }
    }

    // MARK: - Summary Hero

    private var summaryHero: some View {
        GlassContainer(cornerRadius: 20, padding: 20) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "chart.bar.fill")
                        .font(Font.Design.size11)
                        .foregroundStyle(Color.Design.brandAccent)
                    Text("budget_management_hero_eyebrow")
                        .font(Font.Design.size11Medium)
                        .textCase(.uppercase)
                        .tracking(1.2)
                        .foregroundStyle(.secondary)
                }

                Text(totalBudgetAmount.twdFormatted)
                    .font(.system(size: 38, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.top, 2)

                Text(
                    String(
                        format: String(localized: "budget_management_hero_active_count_format"),
                        activeBudgets.count
                    )
                )
                .font(Font.Design.size12)
                .foregroundStyle(.secondary)
                .padding(.top, 6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Budget Section

    private var budgetSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("budget_management_section_categories")
                    .font(Font.Design.size11Medium)
                    .textCase(.uppercase)
                    .tracking(1.2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)

                Spacer()

                Text("budget_management_section_used_of")
                    .font(Font.Design.size12)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
            }

            GlassContainer(cornerRadius: 18, padding: 4) {
                VStack(spacing: 0) {
                    ForEach(Array(store.budgets.enumerated()), id: \.element.id) { index, budget in
                        budgetRowButton(budget)
                        if index < store.budgets.count - 1 {
                            Divider()
                                .padding(.leading, 64)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Row Button

    private func budgetRowButton(_ budget: Budget) -> some View {
        Button {
            store.send(.budgetTapped(budget))
        } label: {
            budgetRow(budget)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                store.send(.budgetTapped(budget))
            } label: {
                Label(String(localized: "common_edit"), systemImage: "pencil")
            }
            Button(role: .destructive) {
                store.send(.deleteRequested(budget.id))
            } label: {
                Label(String(localized: "common_delete"), systemImage: "trash")
            }
        }
    }

    private func budgetRow(_ budget: Budget) -> some View {
        HStack(spacing: 12) {
            budgetIcon(budget)

            VStack(alignment: .leading, spacing: 2) {
                Text(budget.name)
                    .font(Font.Design.body.weight(.semibold))
                    .foregroundStyle(Color.Design.textPrimary)
                Text(budget.period.localizedName)
                    .font(Font.Design.caption)
                    .foregroundStyle(Color.Design.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                // TODO: reducer state does not expose `used` spending per budget.
                // Showing budget amount only until spending data is available in state.
                Text(budget.amount.twdFormatted)
                    .font(Font.Design.amount.monospacedDigit())
                    .foregroundStyle(Color.Design.textPrimary)

                if let breakdown = budget.amount.perPeriodBreakdown(budget.period) {
                    Text(breakdown)
                        .font(Font.Design.size11Monospaced)
                        .foregroundStyle(Color.Design.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .opacity(budget.isActive ? 1.0 : 0.5)
    }

    private func budgetIcon(_ budget: Budget) -> some View {
        // TODO: reducer state does not expose Category objects (icon/color).
        // Using a generic banknote icon with accent color until category map is available in state.
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(iconColor(for: budget))
            .frame(width: 40, height: 40)
            .overlay {
                Image(systemName: "banknote")
                    .font(Font.Design.size18Semibold)
                    .foregroundStyle(.white)
                    .symbolRenderingMode(.hierarchical)
            }
    }

    // MARK: - Helpers

    private var activeBudgets: [Budget] {
        store.budgets.filter(\.isActive)
    }

    private var totalBudgetAmount: Decimal {
        activeBudgets.reduce(Decimal.zero) { $0 + $1.amount }
    }

    private func iconColor(for budget: Budget) -> Color {
        // Cycle through a warm palette until category color lookup is wired up in state.
        let palette: [Color] = [
            Color.Design.brandAccent,
            Color.Design.incomeGreen,
            Color.Design.transferPurple,
            Color.Design.warningAmber,
            Color.Design.accentBlue,
        ]
        let index = abs(budget.id.hashValue) % palette.count
        return palette[index]
    }
}

#Preview {
    NavigationStack {
        BudgetManagementView(
            store: Store(initialState: BudgetManagementFeature.State()) {
                BudgetManagementFeature()
            }
        )
    }
}
