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
        .navigationTitle("預算設定")
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
            title: "尚無預算",
            description: "新增預算來追蹤你的支出目標",
            actionTitle: "新增預算"
        ) {
            store.send(.addButtonTapped)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Budget List

    private var budgetList: some View {
        List {
            ForEach(store.budgets) { budget in
                Button {
                    store.send(.budgetTapped(budget))
                } label: {
                    BudgetRow(budget: budget) {
                        store.send(.toggleActive(budget))
                    }
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        store.send(.deleteRequested(budget.id))
                    } label: {
                        Label("刪除", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
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
