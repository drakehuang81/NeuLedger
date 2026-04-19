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
        List {
            if store.items.isEmpty && !store.isLoading {
                ContentUnavailableView(
                    String(localized: "recurring_transaction_empty_state"),
                    systemImage: "arrow.clockwise.circle"
                )
            } else {
                ForEach(store.items) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.note ?? "—").font(Font.Design.body)
                            Text(item.amount.twdFormatted)
                                .font(Font.Design.amount)
                                .monospacedDigit()
                                .foregroundStyle(Color.Design.textSecondary)
                        }
                        Spacer()
                        Text(item.frequency.localizedName)
                            .font(.caption2).foregroundStyle(.secondary)
                        Toggle("", isOn: Binding(
                            get: { item.isActive },
                            set: { _ in store.send(.toggleActiveTapped(item)) }
                        ))
                        .labelsHidden()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { store.send(.itemTapped(item)) }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            store.send(.deleteTapped(item.id))
                        } label: {
                            Label(String(localized: "common_delete"), systemImage: "trash")
                        }
                    }
                }
            }
        }
        .navigationTitle(String(localized: "recurring_transaction_section_title"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { store.send(.addButtonTapped) } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .task { await store.send(.task).finish() }
        .sheet(item: $store.scope(state: \.form, action: \.form)) { formStore in
            NavigationStack {
                RecurringTransactionFormView(store: formStore)
            }
        }
    }
}
