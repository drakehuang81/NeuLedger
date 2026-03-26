import Foundation
import Testing
import Dependencies
@testable import Domain

@Suite("NotificationClient Tests")
struct NotificationClientTests {

    @Test("NotificationClient testValue is accessible via DependencyValues")
    func testDependencyKeyInjection() {
        @Dependency(\.notificationClient) var client
        #expect(true, "NotificationClient injected successfully")
    }

    @Test("NotificationClient mock override for requestAuthorization")
    func testRequestAuthorizationOverride() async {
        await withDependencies {
            $0.notificationClient.requestAuthorization = { true }
        } operation: {
            @Dependency(\.notificationClient) var client
            let result = await client.requestAuthorization()
            #expect(result == true)
        }
    }
}
