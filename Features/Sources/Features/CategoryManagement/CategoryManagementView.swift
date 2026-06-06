import Common
import ComposableArchitecture
import Domain
import SwiftUI

public struct CategoryManagementView: View {
    @Bindable var store: StoreOf<CategoryManagementFeature>

    public init(store: StoreOf<CategoryManagementFeature>) {
        self.store = store
    }

    public var body: some View {
        ZStack {
            WarmGradientBackground(variant: .top)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                typePicker
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 12)

                Group {
                    if store.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if store.filteredCategories.isEmpty {
                        EmptyStateView(
                            icon: "tag.slash",
                            title: String(localized: "category_management_empty_title"),
                            description: String(localized: "category_management_empty_desc")
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        categoriesList
                    }
                }
            }
        }
        .navigationTitle(String(localized: "category_management_title"))
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
            }
        }
        .task {
            await store.send(.task).finish()
        }
        .sheet(
            item: $store.scope(state: \.addEdit, action: \.addEdit)
        ) { addEditStore in
            AddEditCategoryView(store: addEditStore)
        }
        .alert($store.scope(state: \.alert, action: \.alert))
    }

    // MARK: - Type Picker

    private var typePicker: some View {
        HStack(spacing: 0) {
            typePill(.expense, label: "common_expense")
            typePill(.income, label: "common_income")
        }
        .padding(3)
        .background {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.Design.textPrimary.opacity(0.06))
        }
    }

    private func typePill(_ type: TransactionType, label: LocalizedStringKey) -> some View {
        let isActive = store.selectedType == type
        return Button {
            store.send(.selectedTypeChanged(type))
        } label: {
            Text(label)
                .font(Font.Design.size13Semibold)
                .foregroundStyle(
                    isActive ? Color.Design.textPrimary : Color.Design.textSecondary
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background {
                    if isActive {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Color.Design.surface)
                            .shadow(color: .black.opacity(0.08), radius: 3, y: 1)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Categories List

    // TODO: drag-to-reorder via `.onMove` was dropped during the redesign
    // (requires SwiftUI List). Reintroduce via a long-press context-menu
    // "Move up / Move down" pair that dispatches a (to-be-reintroduced)
    // reorder action re-assigning sortOrder via ledger.updateCategory.
    private var categoriesList: some View {
        ScrollView {
            VStack(spacing: 10) {
                GlassContainer(cornerRadius: 18, padding: 4) {
                    VStack(spacing: 0) {
                        ForEach(Array(store.filteredCategories.enumerated()), id: \.element.id) { index, category in
                            categoryRow(category)
                            if index < store.filteredCategories.count - 1 {
                                Divider()
                                    .padding(.leading, 64)
                            }
                        }
                    }
                }

                Text("category_management_default_hint")
                    .font(Font.Design.size11)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 120)
        }
    }

    private func categoryRow(_ category: Domain.Category) -> some View {
        Button {
            store.send(.categoryTapped(category))
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.Design.fromHex(category.color))
                    .frame(width: 40, height: 40)
                    .overlay {
                        Image(systemName: category.icon)
                            .font(Font.Design.size18Semibold)
                            .foregroundStyle(.white)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(category.localizedName)
                        .font(Font.Design.body.weight(.semibold))
                        .foregroundStyle(Color.Design.textPrimary)

                    if category.isDefault {
                        Text("category_management_default")
                            .font(Font.Design.size10Medium.monospacedDigit())
                            .textCase(.uppercase)
                            .tracking(0.5)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 1)
                            .background(Color.Design.textPrimary.opacity(0.05), in: Capsule())
                    }
                }

                Spacer()

                if !category.isDefault {
                    Image(systemName: "chevron.right")
                        .font(Font.Design.size12Semibold)
                        .foregroundStyle(Color.Design.textTertiary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            if !category.isDefault {
                Button {
                    store.send(.categoryTapped(category))
                } label: {
                    Label(String(localized: "common_edit"), systemImage: "pencil")
                }
                Button(role: .destructive) {
                    store.send(.deleteRequested(category.id))
                } label: {
                    Label(String(localized: "common_delete"), systemImage: "trash")
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        CategoryManagementView(
            store: Store(initialState: CategoryManagementFeature.State()) {
                CategoryManagementFeature()
            }
        )
    }
}
