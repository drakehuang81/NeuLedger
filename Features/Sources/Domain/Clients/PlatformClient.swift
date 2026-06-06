import Foundation
import Dependencies
import DependenciesMacros

/// A client interface for app-platform concerns that have no domain owner —
/// device preferences, local notifications, iCloud sync lifecycle, inbound
/// link routing, and system integration.
///
/// `PlatformClient` consolidates what previously lived across
/// `AppEnvironmentUseCase` (preferences + notifications + app-settings),
/// `CloudSyncUseCase` (iCloud sync), and `DeeplinkClient` (link routing).
/// The Features layer drives all these cross-cutting platform concerns
/// through this single client.
///
/// Note: `defaultAccountId` / `setDefaultAccountId` are intentionally **not**
/// part of this surface — they move to `LedgerClient` (step 5).
@DependencyClient
public struct PlatformClient: Sendable {

    // MARK: - Preferences

    /// The user's preferred accessory-bar mode (quick-add vs. AI).
    public var accessoryMode: @Sendable () -> AccessoryMode = { .add }
    /// Sets the user's preferred accessory-bar mode.
    public var setAccessoryMode: @Sendable (_ mode: AccessoryMode) -> Void

    /// The wall-clock time at which the daily recording reminder fires.
    public var reminderTime: @Sendable () -> ReminderTime = { ReminderTime(hour: 21, minute: 0) }
    /// Sets the daily recording reminder time.
    public var setReminderTime: @Sendable (_ time: ReminderTime) -> Void

    /// Whether the daily recording reminder notification is enabled.
    public var dailyReminderEnabled: @Sendable () -> Bool = { false }
    /// Sets whether the daily recording reminder notification is enabled.
    public var setDailyReminderEnabled: @Sendable (_ enabled: Bool) -> Void

    /// Whether the user has completed the onboarding flow.
    public var hasCompletedOnboarding: @Sendable () -> Bool = { false }
    /// Flips the onboarding-complete flag to `true`.
    public var markOnboardingComplete: @Sendable () -> Void

    /// Whether the bottom accessory bar (AI record + quick add) is visible.
    public var showAccessoryBar: @Sendable () -> Bool = { true }
    /// Sets whether the bottom accessory bar is visible.
    public var setShowAccessoryBar: @Sendable (_ visible: Bool) -> Void

    /// `true` if a paired Apple Watch is currently associated with this iPhone.
    public var watchPaired: @Sendable () -> Bool = { false }
    /// `true` if the watchOS companion app is installed on the paired Watch.
    public var watchAppInstalled: @Sendable () -> Bool = { false }
    /// The default account used when recording transactions from Apple Watch,
    /// or `nil` when no override is set (falls back to the sortOrder-first
    /// active account at snapshot time).
    public var watchDefaultAccountId: @Sendable () -> Account.ID? = { nil }
    /// Sets the Apple Watch default account override. Passing `nil` clears it.
    public var setWatchDefaultAccountId: @Sendable (_ id: Account.ID?) -> Void
    /// Rebuilds the Watch context snapshot (validating the stored default
    /// account against live accounts) and pushes it to the Watch immediately.
    /// Settings writes don't save SwiftData, so the save-observer never fires
    /// for them — call this after mutating Watch-related settings. Failures
    /// are swallowed: WC retries and the next SwiftData save re-pushes anyway.
    public var pushWatchContext: @Sendable () async -> Void

    // MARK: - Notification

    /// Requests notification authorization. Returns `true` if granted.
    public var requestNotificationPermission: @Sendable () async -> Bool = { false }
    /// Current notification authorization status (`true` = authorized).
    public var notificationsAuthorized: @Sendable () async -> Bool = { false }
    /// Schedules (or reschedules) the daily reminder at the stored time.
    public var scheduleDailyReminder: @Sendable () async throws -> Void
    /// Cancels the daily reminder.
    public var cancelDailyReminder: @Sendable () async -> Void
    /// AppFeature inbound-notification routing subscription — emits a
    /// `RecurringTransaction.ID` each time the user taps a recurring-transaction
    /// notification. Replaces the former direct `notificationAdapter` injection.
    public var pendingRecurringConfirmations: @Sendable () -> AsyncStream<RecurringTransaction.ID> = {
        let (stream, continuation) = AsyncStream<RecurringTransaction.ID>.makeStream()
        continuation.finish()
        return stream
    }

    // MARK: - Sync

    /// Whether the device has an active iCloud account available for sync.
    public var syncAvailable: @Sendable () -> Bool = { false }
    /// Whether the user has enabled CloudKit-backed sync.
    public var syncEnabled: @Sendable () -> Bool = { false }
    /// The timestamp of the last successful CloudKit sync, or `nil`.
    public var lastSyncedAt: @Sendable () -> Date? = { nil }
    /// Enables CloudKit sync — yields progress (0.0–1.0) and finishes on
    /// success; throws on failure.
    public var enableSync: @Sendable () -> AsyncThrowingStream<Double, Error> = { .finished() }
    /// Nudges CloudKit to flush pending changes and updates `lastSyncedAt`.
    public var requestSyncNow: @Sendable () async throws -> Void = {}
    /// Destructively wipes all local + CloudKit data and resets preference flags.
    public var wipeAllSyncData: @Sendable () async throws -> Void = {}

    // MARK: - Routing

    /// Resolves an inbound URL into a navigation destination.
    public var parseLink: @Sendable (URL) async throws -> RouteLinkDestination
    /// Whether onboarding can be skipped (i.e. it was already completed).
    public var canSkipOnboarding: @Sendable () async throws -> Bool
    /// Resolves a recurring-transaction id into a confirmation destination.
    public var resolveRecurringConfirmation: @Sendable (_ id: RecurringTransaction.ID) async throws -> RouteLinkDestination

    // MARK: - System

    /// Opens the iOS system Settings app at this app's preferences page.
    /// Fire-and-forget — call sites do not await.
    public var openAppSettings: @Sendable () -> Void

    /// Records a non-fatal error to the crash-reporting backend.
    /// Fire-and-forget — call sites do not await.
    public var recordError: @Sendable (_ error: any Error, _ userInfo: [String: String]) -> Void
}

// MARK: - TestDependencyKey

extension PlatformClient: TestDependencyKey {
    public static let testValue = Self()
}

// MARK: - DependencyValues

public extension DependencyValues {
    var platformClient: PlatformClient {
        get { self[PlatformClient.self] }
        set { self[PlatformClient.self] = newValue }
    }
}
