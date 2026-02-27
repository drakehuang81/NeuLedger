import SwiftUI
import SwiftData
import Features
import Core
import Dependencies

@main
struct NeuLedgerApp: App {
    @Dependency(\.databaseClient) var databaseClient

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(databaseClient.modelContainer())
    }
}
