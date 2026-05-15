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
        ZStack {
            WarmGradientBackground(variant: .top)
                .ignoresSafeArea()

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
        }
        .navigationTitle(String(localized: "tag_management_title"))
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
        ScrollView {
            VStack(spacing: 18) {
                chipOverviewSection
                detailListSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 120)
        }
    }

    // MARK: - Chip Overview Section

    private var chipOverviewSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(String(format: String(localized: "tag_management_all_count_format"), store.tags.count))
                .font(.system(size: 11, weight: .medium).monospacedDigit())
                .textCase(.uppercase)
                .tracking(1.2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.bottom, 10)

            FlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                ForEach(store.tags) { tag in
                    tagChip(tag)
                }
            }
        }
    }

    private func tagChip(_ tag: Tag) -> some View {
        let color = tag.color.map { Color(hex: $0) } ?? Color.Design.accentOrange
        return HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text("#\(tag.name)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(color)
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 12)
        .background(color.opacity(0.13), in: Capsule())
        .overlay(Capsule().strokeBorder(color.opacity(0.33), lineWidth: 1))
    }

    // MARK: - Detail List Section

    private var detailListSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("tag_management_usage_section")
                .font(.system(size: 11, weight: .medium).monospacedDigit())
                .textCase(.uppercase)
                .tracking(1.2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.bottom, 8)

            GlassContainer(cornerRadius: 18, padding: 4) {
                VStack(spacing: 0) {
                    ForEach(Array(store.tags.enumerated()), id: \.element.id) { index, tag in
                        tagDetailRow(tag)
                        if index < store.tags.count - 1 {
                            Divider()
                                .padding(.leading, 64)
                        }
                    }
                }
            }

            Text("tag_management_delete_hint")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.top, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func tagDetailRow(_ tag: Tag) -> some View {
        let color = tag.color.map { Color(hex: $0) } ?? Color.Design.accentOrange
        return Button {
            store.send(.tagTapped(tag))
        } label: {
            HStack(spacing: 12) {
                // Color circle with # symbol
                ZStack {
                    Circle()
                        .fill(color.opacity(0.13))
                        .overlay(Circle().strokeBorder(color, lineWidth: 1.5))
                        .frame(width: 36, height: 36)
                    Text("#")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(tag.name)
                        .font(Font.Design.body.weight(.semibold))
                        .foregroundStyle(Color.Design.textPrimary)

                    if let hex = tag.color {
                        Text(hex.uppercased())
                            .font(.system(size: 11).monospacedDigit())
                            .tracking(0.3)
                            .foregroundStyle(Color.Design.textSecondary)
                    }
                }

                Spacer()

                // TODO: Show real usage count when tagClient exposes it
                VStack(alignment: .trailing, spacing: 1) {
                    Text("—")
                        .font(.system(size: 13, weight: .semibold).monospacedDigit())
                        .foregroundStyle(Color.Design.textPrimary)
                    Text("TXNS")
                        .font(.system(size: 10).monospacedDigit())
                        .tracking(0.5)
                        .foregroundStyle(Color.Design.textSecondary)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.Design.textTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                store.send(.tagTapped(tag))
            } label: {
                Label(String(localized: "common_edit"), systemImage: "pencil")
            }
            Button(role: .destructive) {
                store.send(.deleteRequested(tag.id))
            } label: {
                Label(String(localized: "common_delete"), systemImage: "trash")
            }
        }
    }
}

#Preview {
    NavigationStack {
        TagManagementView(
            store: Store(initialState: TagManagementFeature.State()) {
                TagManagementFeature()
            }
        )
    }
}
