import Testing
import Dependencies
@testable import Domain

@Suite("UserSettingsRepository Tests")
struct UserSettingsRepositoryTests {

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
        let client = UserSettingsRepository.testValue
        let result = client.bool(.hasCompletedOnboarding)
        #expect(result == SettingsKey.hasCompletedOnboarding.defaultValue)
    }

    // MARK: - Int Keys

    @Test("dailyReminderHour key has correct rawValue and defaultValue")
    func testDailyReminderHourKey() {
        let key = SettingsKey<Int>.dailyReminderHour
        #expect(key.rawValue == "dailyReminderHour")
        #expect(key.defaultValue == 21)
    }

    @Test("dailyReminderMinute key has correct rawValue and defaultValue")
    func testDailyReminderMinuteKey() {
        let key = SettingsKey<Int>.dailyReminderMinute
        #expect(key.rawValue == "dailyReminderMinute")
        #expect(key.defaultValue == 0)
    }

    @Test("budgetWarningThreshold key has correct rawValue and defaultValue")
    func testBudgetWarningThresholdKey() {
        let key = SettingsKey<Int>.budgetWarningThreshold
        #expect(key.rawValue == "budgetWarningThreshold")
        #expect(key.defaultValue == 80)
    }

    @Test("testValue int returns defaultValue")
    func testTestValueIntReturnsDefault() {
        let client = UserSettingsRepository.testValue
        let result = client.int(.dailyReminderHour)
        #expect(result == SettingsKey.dailyReminderHour.defaultValue)
    }

    // MARK: - Bool Keys (notification)

    @Test("dailyReminderEnabled key has correct rawValue and defaultValue")
    func testDailyReminderEnabledKey() {
        let key = SettingsKey<Bool>.dailyReminderEnabled
        #expect(key.rawValue == "dailyReminderEnabled")
        #expect(key.defaultValue == false)
    }

    @Test("budgetWarningEnabled key has correct rawValue and defaultValue")
    func testBudgetWarningEnabledKey() {
        let key = SettingsKey<Bool>.budgetWarningEnabled
        #expect(key.rawValue == "budgetWarningEnabled")
        #expect(key.defaultValue == false)
    }
}
