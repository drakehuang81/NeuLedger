import Common
import ComposableArchitecture
import Domain
import SwiftUI

public struct AccountManagementView: View {
    @Bindable var store: StoreOf<AccountManagementFeature>

    public init(store: StoreOf<AccountManagementFeature>) {
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
                } else if store.accounts.isEmpty {
                    EmptyStateView(
                        icon: "wallet.bifold",
                        title: String(localized: "account_management_empty_title"),
                        description: String(localized: "account_management_empty_desc"),
                        actionTitle: String(localized: "account_management_add")
                    ) {
                        store.send(.addButtonTapped)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    accountList
                }
            }
        }
        .navigationTitle(String(localized: "account_management_title"))
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    store.send(.addButtonTapped)
                } label: {
                    Image(systemName: "plus")
                        .font(Font.Design.size17Semibold)
                }
                .accessibilityLabel(String(localized: "a11y_account_add"))
            }
        }
        .task { await store.send(.task).finish() }
        .sheet(
            item: $store.scope(state: \.addEdit, action: \.addEdit)
        ) { addEditStore in
            AddEditAccountView(store: addEditStore)
        }
        .alert($store.scope(state: \.alert, action: \.alert))
    }

    // MARK: - Account List

    // TODO: drag-to-reorder is intentionally dropped — `.onMove` requires
    // SwiftUI `List` and we use ScrollView+GlassContainer here. Reintroduce
    // via a long-press "Move up / Move down" context-menu action or a
    // dedicated reorder mode that dispatches a (to-be-reintroduced) reorder
    // action re-assigning sortOrder via ledger.updateAccount.
    private var accountList: some View {
        ScrollView {
            VStack(spacing: 18) {
                netWorthHero

                ForEach(activeGroups, id: \.id) { group in
                    groupSection(label: group.label, accounts: group.accounts)
                }

                if !store.archivedAccounts.isEmpty {
                    archivedSection
                }

                addAccountButton
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 120)
        }
    }

    // MARK: - Net Worth Hero

    // TODO: design shows "↑ NT$ 12,450 比上月" delta line under the total.
    // The reducer doesn't track a prior-period total today; surface it via
    // AccountManagementFeature.State once we want to render the delta.
    private var netWorthHero: some View {
        GlassContainer(cornerRadius: 22, padding: 22) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkle")
                        .font(Font.Design.size11)
                        .foregroundStyle(Color.Design.brandAccent)
                    Text("account_management_net_worth")
                        .font(Font.Design.size11Medium)
                        .textCase(.uppercase)
                        .tracking(1.2)
                        .foregroundStyle(.secondary)
                }
                Text(totalBalance.twdFormatted)
                    .font(Font.Design.size38Semibold.monospacedDigit())
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.top, 2)
                Text(
                    String(
                        format: String(localized: "account_management_account_count_format"),
                        store.accounts.count
                    )
                )
                .font(Font.Design.size12)
                .foregroundStyle(.secondary)
                .padding(.top, 6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Group Section

    private func groupSection(label: LocalizedStringKey, accounts: [Account]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(Font.Design.size11Medium)
                .textCase(.uppercase)
                .tracking(1.2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)

            GlassContainer(cornerRadius: 18, padding: 4) {
                VStack(spacing: 0) {
                    ForEach(Array(accounts.enumerated()), id: \.element.id) { index, account in
                        accountRowButton(account)
                        if index < accounts.count - 1 {
                            Divider()
                                .padding(.leading, 64)
                        }
                    }
                }
            }
        }
    }

    private var archivedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("account_management_archived")
                .font(Font.Design.size11Medium)
                .textCase(.uppercase)
                .tracking(1.2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)

            GlassContainer(cornerRadius: 18, padding: 4) {
                VStack(spacing: 0) {
                    ForEach(Array(store.archivedAccounts.enumerated()), id: \.element.id) { index, account in
                        archivedAccountRow(account)
                            .contextMenu {
                                Button {
                                    store.send(.unarchiveTapped(account.id))
                                } label: {
                                    Label(String(localized: "account_management_unarchive"), systemImage: "tray.and.arrow.up")
                                }
                                Button(role: .destructive) {
                                    store.send(.deleteRequested(account.id))
                                } label: {
                                    Label(String(localized: "common_delete"), systemImage: "trash")
                                }
                            }
                        if index < store.archivedAccounts.count - 1 {
                            Divider()
                                .padding(.leading, 64)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Row Views

    private func accountRowButton(_ account: Account) -> some View {
        Button {
            store.send(.accountTapped(account))
        } label: {
            accountRow(account)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                store.send(.accountTapped(account))
            } label: {
                Label(String(localized: "common_edit"), systemImage: "pencil")
            }
            Button(role: .destructive) {
                store.send(.deleteRequested(account.id))
            } label: {
                Label(String(localized: "common_delete"), systemImage: "trash")
            }
        }
    }

    private func accountRow(_ account: Account) -> some View {
        HStack(spacing: 12) {
            accountIcon(account)
            VStack(alignment: .leading, spacing: 2) {
                Text(account.name)
                    .font(Font.Design.body.weight(.semibold))
                    .foregroundStyle(Color.Design.textPrimary)
                Text(account.type.displayLabel)
                    .font(Font.Design.caption)
                    .foregroundStyle(Color.Design.textSecondary)
            }
            Spacer()
            Text(balanceText(for: account.id))
                .font(Font.Design.amount.monospacedDigit())
                .foregroundStyle(balanceColor(for: account.id))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private func archivedAccountRow(_ account: Account) -> some View {
        HStack(spacing: 12) {
            accountIcon(account)
                .opacity(0.5)
            VStack(alignment: .leading, spacing: 2) {
                Text(account.name)
                    .font(Font.Design.body)
                    .foregroundStyle(Color.Design.textSecondary)
                Text(account.type.displayLabel)
                    .font(Font.Design.caption)
                    .foregroundStyle(Color.Design.textTertiary)
            }
            Spacer()
            Text("account_management_archived")
                .font(Font.Design.caption)
                .foregroundStyle(Color.Design.textTertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private func accountIcon(_ account: Account) -> some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.Design.fromHex(account.color))
            .frame(width: 40, height: 40)
            .overlay {
                Image(systemName: account.icon)
                    .font(Font.Design.size18Semibold)
                    .foregroundStyle(.white)
            }
    }

    // MARK: - Add Button

    private var addAccountButton: some View {
        Button {
            store.send(.addButtonTapped)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(Font.Design.size14Semibold)
                Text("account_management_add")
                    .font(Font.Design.size14Semibold)
            }
            .foregroundStyle(Color.Design.brandAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        Color.Design.brandAccent.opacity(0.45),
                        style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])
                    )
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private var totalBalance: Decimal {
        store.balances.values.reduce(Decimal.zero, +)
    }

    // TODO: design includes Invest + Crypto groups, but AccountType only
    // defines .cash / .bank / .creditCard / .eWallet. Add the new cases to
    // Domain.AccountType (and seed defaults) before rendering those groups.
    private var activeGroups: [AccountGroup] {
        let active = store.activeAccounts
        let buckets: [(id: String, label: LocalizedStringKey, types: [AccountType])] = [
            ("liquid", "account_management_group_liquid", [.cash, .bank]),
            ("credit", "account_management_group_credit", [.creditCard]),
            ("digital", "account_management_group_digital", [.eWallet])
        ]
        return buckets.compactMap { bucket in
            let accs = active.filter { bucket.types.contains($0.type) }
            guard !accs.isEmpty else { return nil }
            return AccountGroup(id: bucket.id, label: bucket.label, accounts: accs)
        }
    }

    private func balanceText(for id: Account.ID) -> String {
        let balance = store.balances[id] ?? 0
        return balance.twdFormatted
    }

    private func balanceColor(for id: Account.ID) -> Color {
        let balance = store.balances[id] ?? 0
        return balance < 0 ? Color.Design.expenseRed : Color.Design.textPrimary
    }
}

// MARK: - Local Types

private struct AccountGroup {
    let id: String
    let label: LocalizedStringKey
    let accounts: [Account]
}

#Preview {
    NavigationStack {
        AccountManagementView(
            store: Store(initialState: AccountManagementFeature.State()) {
                AccountManagementFeature()
            }
        )
    }
}
