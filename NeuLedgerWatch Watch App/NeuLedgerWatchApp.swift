import SwiftUI
import ComposableArchitecture
import WatchFeatures

@main
struct NeuLedgerWatch_Watch_AppApp: App {

    init() {
        prepareDependencies { dependencies in
            WatchDependencies.register(in: &dependencies)
        }
    }

    var body: some Scene {
        WindowGroup {
            WatchRootView(
                store: Store(initialState: WatchRecordFeature.State()) {
                    WatchRecordFeature()
                }
            )
        }
    }
}
