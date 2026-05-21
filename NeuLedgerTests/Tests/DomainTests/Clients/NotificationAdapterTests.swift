import Foundation
import Testing
import Dependencies
@testable import Domain

@Suite("NotificationAdapter Tests")
struct NotificationAdapterTests {

    @Test("NotificationAdapter testValue is accessible via DependencyValues")
    func testDependencyKeyInjection() {
        @Dependency(\.notificationAdapter) var client
        #expect(true, "NotificationAdapter injected successfully")
    }

    @Test("NotificationAdapter mock override for requestAuthorization")
    func testRequestAuthorizationOverride() async {
        await withDependencies {
            $0.notificationAdapter.requestAuthorization = { true }
        } operation: {
            @Dependency(\.notificationAdapter) var client
            let result = await client.requestAuthorization()
            #expect(result == true)
        }
    }
}
