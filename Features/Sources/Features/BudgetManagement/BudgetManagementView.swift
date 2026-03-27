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
        .navigationTitle(String(localized: "settings_budget_management"))
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
                        Label(String(localized: "common_delete"), systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .padding(.bottom, 100)
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
