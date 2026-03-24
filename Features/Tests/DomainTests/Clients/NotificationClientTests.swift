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

    @Test("testValue requestAuthorization returns false")
    func testRequestAuthorizationDefault() async {
        let client = NotificationClient.testValue
        let result = await client.requestAuthorization()
        #expect(result == false)
    }

    @Test("testValue isAuthorized returns false")
    func testIsAuthorizedDefault() async {
        let client = NotificationClient.testValue
        let result = await client.isAuthorized()
        #expect(result == false)
    }

    @Test("testValue lastWarnedPercent returns nil")
    func testLastWarnedPercentDefault() {
        let client = NotificationClient.testValue
        let result = client.lastWarnedPercent("budget-id", "2026-03-01")
        #expect(result == nil)
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
