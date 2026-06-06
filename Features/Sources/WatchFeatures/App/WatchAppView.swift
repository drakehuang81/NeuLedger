import SwiftUI
import ComposableArchitecture

/// Top-level Watch view: vertical-page TabView between record (page 1)
/// and carriers (page 2). The carrier page is removed from the hierarchy
/// while paging is locked (mid-entry), which disables the swipe without
/// touching the record flow.
public struct WatchAppView: View {

    @Bindable public var store: StoreOf<WatchAppFeature>

    public init(store: StoreOf<WatchAppFeature>) {
        self.store = store
    }

    public var body: some View {
        TabView(selection: $store.tab) {
            WatchRootView(
                store: store.scope(state: \.record, action: \.record)
            )
            .tag(WatchAppFeature.Tab.record)

            // Removing a tag the selection might point at is safe only
            // because of a cross-reducer invariant: while the carrier page
            // is visible, `record.step` is always `.category` (only
            // user-initiated record actions mutate `step`; async reloads
            // like `.loaded` never do). If a future action breaks that,
            // this removal strands the TabView selection.
            if store.isPagingLocked == false {
                WatchCarrierView(
                    store: store.scope(state: \.carrier, action: \.carrier)
                )
                .tag(WatchAppFeature.Tab.carrier)
            }
        }
        .tabViewStyle(.verticalPage)
    }
}
