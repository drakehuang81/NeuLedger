import Foundation
import Testing
import Dependencies
@testable import Domain

@Suite("WatchBridgeAdapter Tests")
struct WatchBridgeAdapterTests {

    @Test("testValue is resolvable via DependencyValues and reports safe defaults")
    func testValueIsResolvable() {
        withDependencies {
            $0.watchBridgeAdapter.isPaired = { false }
            $0.watchBridgeAdapter.isWatchAppInstalled = { false }
        } operation: {
            @Dependency(\.watchBridgeAdapter) var adapter
            #expect(adapter.isPaired() == false)
            #expect(adapter.isWatchAppInstalled() == false)
        }
    }
}
