import Foundation
import Dependencies
import DependenciesMacros

/// Application-layer use case for app-wide environment concerns —
/// preferences, notifications, and the System app-settings deep link.
///
/// Surface follows `docs/architecture.md` §5 App Environment Context.
/// Lives in the Application layer so feature reducers stop reaching
/// directly into the `UserSettingsAdapter` / `NotificationAdapter` /
/// `UIApplication` triumvirate.
@DependencyClient
public struct AppEnvironmentUseCase: Sendable {
    // MARK: - Preferences

    public var accessoryMode: @Sendable () -> AccessoryMode = { .add }
    public var setAccessoryMode: @Sendable (_ mode: AccessoryMode) -> Void

    public var reminderTime: @Sendable () -> ReminderTime = { ReminderTime(hour: 21, minute: 0) }
    public var setReminderTime: @Sendable (_ time: ReminderTime) -> Void

    public var dailyReminderEnabled: @Sendable () -> Bool = { false }
    public var setDailyReminderEnabled: @Sendable (_ enabled: Bool) -> Void

    /// User's preferred default account for new transactions. `nil` if
    /// none selected (first launch or the stored id is unparseable).
    public var defaultAccountId: @Sendable () -> Account.ID? = { nil }
    public var setDefaultAccountId: @Sendable (_ id: Account.ID?) -> Void

    public var hasCompletedOnboarding: @Sendable () -> Bool = { false }
    public var markOnboardingComplete: @Sendable () -> Void

    // MARK: - Notifications

    public var requestNotificationPermission: @Sendable () async -> Bool = { false }
    public var scheduleDailyReminder: @Sendable () async throws -> Void
    public var cancelDailyReminder: @Sendable () async -> Void

    // MARK: - System

    /// Open the iOS system Settings app at this app's preferences page.
    /// Fire-and-forget — call sites do not await.
    public var openAppSettings: @Sendable () -> Void
}

extension AppEnvironmentUseCase: TestDependencyKey {
    public static let testValue = Self()
}

public extension DependencyValues {
    var appEnvironmentUseCase: AppEnvironmentUseCase {
        get { self[AppEnvironmentUseCase.self] }
        set { self[AppEnvironmentUseCase.self] = newValue }
    }
}
