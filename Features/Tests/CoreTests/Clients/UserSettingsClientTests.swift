import Testing
import Dependencies
@testable import Domain

@Suite("UserSettingsClient Tests")
struct UserSettingsClientTests {

    // MARK: - SettingsKey

    @Test("hasCompletedOnboarding key has correct rawValue")
    func testHasCompletedOnboardingRawValue() {
        let key = SettingsKey<Bool>.hasCompletedOnboarding
        #expect(key.rawValue == "hasCompletedOnboarding")
    }

    @Test("hasCompletedOnboarding key has correct defaultValue")
    func testHasCompletedOnboardingDefaultValue() {
        let key = SettingsKey<Bool>.hasCompletedOnboarding
        #expect(key.defaultValue == false)
    }

    // MARK: - Test Value Defaults

    @Test("testValue bool returns defaultValue for any key")
    func testTestValueBoolReturnsDefault() {
        let client = UserSettingsClient.testValue
        let result = client.bool(.hasCompletedOnboarding)
        #expect(result == SettingsKey.hasCompletedOnboarding.defaultValue)
    }
}
