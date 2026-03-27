import Common
import ComposableArchitecture
import Domain
import SwiftUI

public struct TagManagementView: View {
    @Bindable var store: StoreOf<TagManagementFeature>

    public init(store: StoreOf<TagManagementFeature>) {
        self.store = store
    }

    public var body: some View {
        Group {
            if store.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if store.tags.isEmpty {
                emptyState
            } else {
                tagList
            }
        }
        .navigationTitle(String(localized: "tag_management_title"))
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
        .sheet(item: $store.scope(state: \.addEdit, action: \.addEdit)) { addEditStore in
            AddEditTagView(store: addEditStore)
        }
        .alert($store.scope(state: \.alert, action: \.alert))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        EmptyStateView(
            icon: "tag",
            title: String(localized: "tag_management_empty_title"),
            description: String(localized: "tag_management_empty_desc"),
            actionTitle: String(localized: "tag_management_add")
        ) {
            store.send(.addButtonTapped)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Tag List

    private var tagList: some View {
        List {
            ForEach(store.tags) { tag in
                Button {
                    store.send(.tagTapped(tag))
                } label: {
                    tagRow(tag)
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        store.send(.deleteRequested(tag.id))
                    } label: {
                        Label(String(localized: "common_delete"), systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .padding(.bottom, 100)
    }

    private func tagRow(_ tag: Tag) -> some View {
        TagPill(
            text: tag.name,
            color: tag.color.map { Color(hex: $0) }
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }
}
