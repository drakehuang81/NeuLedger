import SwiftUI
import ComposableArchitecture
import Domain
import Common

// Temporary stub — replaced by real view in Task 8.
struct ConfirmView: View {
    let store: StoreOf<WatchRecordFeature>
    var body: some View { Text("confirm") }
}

/// Top-level view for the Apple Watch quick-record flow. Routes between
/// the three steps based on `state.step`.
public struct WatchRootView: View {

    @Bindable public var store: StoreOf<WatchRecordFeature>

    public init(store: StoreOf<WatchRecordFeature>) {
        self.store = store
    }

    public var body: some View {
        Group {
            switch store.step {
            case .category:
                CategoryGridView(store: store)
            case .amount:
                AmountKeypadView(store: store)
            case .confirm:
                ConfirmView(store: store)
            }
        }
        .task { await store.send(.task).finish() }
        .sheet(
            isPresented: Binding(
                get: { store.accountPickerForCategoryId != nil },
                set: { newValue in
                    if newValue == false { store.send(.accountPickerDismissed) }
                }
            )
        ) {
            AccountPickerSheet(store: store)
        }
    }
}

/// Sheet content for long-press account override.
struct AccountPickerSheet: View {

    let store: StoreOf<WatchRecordFeature>

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                ForEach(store.accounts, id: \.id) { account in
                    Button {
                        store.send(.accountPicked(account.id))
                    } label: {
                        HStack {
                            Image(systemName: account.icon)
                                .foregroundStyle(Color.Design.fromHex(account.color))
                            Text(account.name)
                                .font(Font.Design.body)
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
    }
}
