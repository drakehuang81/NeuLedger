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
        Group {
            if store.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if store.accounts.isEmpty {
                EmptyStateView(
                    icon: "wallet.bifold",
                    title: "尚無帳戶",
                    description: "新增您的第一個帳戶開始記帳",
                    actionTitle: "新增帳戶"
                ) {
                    store.send(.addButtonTapped)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                accountList
            }
        }
        .navigationTitle("帳戶管理")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    store.send(.addButtonTapped)
                } label: {
                    Image(systemName: "plus")
                }
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

    private var accountList: some View {
        List {
            Section("啟用中") {
                ForEach(store.activeAccounts) { account in
                    Button {
                        store.send(.accountTapped(account))
                    } label: {
                        accountRow(account)
                    }
                    .buttonStyle(.plain)
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        let account = store.activeAccounts[index]
                        store.send(.deleteRequested(account.id))
                    }
                }
            }

            if !store.archivedAccounts.isEmpty {
                Section("已封存") {
                    ForEach(store.archivedAccounts) { account in
                        archivedAccountRow(account)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    store.send(.deleteRequested(account.id))
                                } label: {
                                    Label("刪除", systemImage: "trash")
                                }
                                Button {
                                    store.send(.unarchiveTapped(account.id))
                                } label: {
                                    Label("解除封存", systemImage: "tray.and.arrow.up")
                                }
                                .tint(Color.Design.brandPrimary)
                            }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Row Views

    private func accountRow(_ account: Account) -> some View {
        HStack(spacing: 12) {
            accountIcon(account)
            VStack(alignment: .leading, spacing: 2) {
                Text(account.name)
                    .font(Font.Design.body)
                    .foregroundStyle(Color.Design.textPrimary)
                Text(account.type.displayLabel)
                    .font(Font.Design.caption)
                    .foregroundStyle(Color.Design.textSecondary)
            }
            Spacer()
            Text(balanceText(for: account.id))
                .font(Font.Design.amount)
                .foregroundStyle(Color.Design.textPrimary)
        }
        .padding(.vertical, 4)
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
            Text("已封存")
                .font(Font.Design.caption)
                .foregroundStyle(Color.Design.textTertiary)
        }
        .padding(.vertical, 4)
    }

    private func accountIcon(_ account: Account) -> some View {
        ZStack {
            Circle()
                .fill(Color(hex: account.color).opacity(0.15))
                .frame(width: 40, height: 40)
            Image(systemName: account.icon)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color(hex: account.color))
                .font(.system(size: 18))
        }
    }

    // MARK: - Helpers

    private func balanceText(for id: Account.ID) -> String {
        let balance = store.balances[id] ?? 0
        return "NT$\(balance.formatted(.number.precision(.fractionLength(0))))"
    }
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
