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
        .navigationTitle(String(localized: "category_management_title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                EditButton()
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    store.send(.addButtonTapped)
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .safeAreaInset(edge: .top) {
            typePicker
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.Design.background)
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
        Picker(
            String(localized: "common_type"),
            selection: Binding(
                get: { store.selectedType },
                set: { store.send(.selectedTypeChanged($0)) }
            )
        ) {
            Text("common_expense").tag(TransactionType.expense)
            Text("common_income").tag(TransactionType.income)
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Categories List

    private var categoriesList: some View {
        List {
            ForEach(store.filteredCategories) { category in
                categoryRow(category)
            }
            .onMove { from, to in
                store.send(.categoriesMoved(from, to))
            }
        }
        .listStyle(.insetGrouped)
//        .padding(.bottom, 100)
    }

    private func categoryRow(_ category: Domain.Category) -> some View {
        Button {
            store.send(.categoryTapped(category))
        } label: {
            HStack(spacing: 12) {
                // Colored icon circle
                ZStack {
                    Circle()
                        .fill(Color(hex: category.color))
                        .frame(width: 40, height: 40)
                    Image(systemName: category.icon)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Color.Design.textInverse)
                        .font(.system(size: 18, weight: .medium))
                }

                // Name + default badge
                VStack(alignment: .leading, spacing: 2) {
                    Text(category.localizedName)
                        .font(Font.Design.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.Design.textPrimary)

                    if category.isDefault {
                        Text("category_management_default")
                            .font(Font.Design.caption)
                            .foregroundStyle(Color.Design.textSecondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.Design.surfaceSecondary, in: Capsule())
                    }
                }

                Spacer()

                if !category.isDefault {
                    Image(systemName: "chevron.right")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Color.Design.textTertiary)
                        .font(.caption)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if !category.isDefault {
                Button(role: .destructive) {
                    store.send(.deleteRequested(category.id))
                } label: {
                    Label(String(localized: "common_delete"), systemImage: "trash")
                }
            }
        }
    }
}
