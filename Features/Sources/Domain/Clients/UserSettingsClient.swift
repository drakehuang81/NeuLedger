import Foundation
import Dependencies
import DependenciesMacros

// MARK: - SettingsKey

/// A type-safe key for reading and writing values in UserDefaults.
///
/// Use constrained extensions to define keys grouped by value type:
/// ```swift
/// extension SettingsKey where Value == Bool {
///     static let hasCompletedOnboarding = SettingsKey(
///         rawValue: "hasCompletedOnboarding",
///         defaultValue: false
///     )
/// }
/// ```
public struct SettingsKey<Value>: Sendable where Value: Sendable {
    /// The raw string key used in UserDefaults.
    public let rawValue: String

    /// The default value returned when the key has not been set.
    public let defaultValue: Value

    public init(rawValue: String, defaultValue: Value) {
        self.rawValue = rawValue
        self.defaultValue = defaultValue
    }
}

// MARK: - Bool Keys

public extension SettingsKey where Value == Bool {
    /// Whether the user has completed the onboarding flow.
    static let hasCompletedOnboarding = SettingsKey(
        rawValue: "hasCompletedOnboarding",
        defaultValue: false
    )

    /// Whether the bottom accessory bar (AI record + quick add) is visible.
    static let showAccessoryBar = SettingsKey(
        rawValue: "showAccessoryBar",
        defaultValue: true
    )


    /// Whether the daily recording reminder notification is enabled.
    static let dailyReminderEnabled = SettingsKey(
        rawValue: "dailyReminderEnabled",
        defaultValue: false
    )

    /// Whether budget overspend warning notifications are enabled.
    static let budgetWarningEnabled = SettingsKey(
        rawValue: "budgetWarningEnabled",
        defaultValue: false
    )
}

// MARK: - String Keys

public extension SettingsKey where Value == String {
    /// The ID of the user's preferred default account for new transactions.
    static let defaultAccountId = SettingsKey(
        rawValue: "defaultAccountId",
        defaultValue: ""
    )

    /// The user's preferred accessory bar mode ("add" or "ai"). Default: "add".
    static let accessoryMode = SettingsKey(
        rawValue: "accessoryMode",
        defaultValue: "add"
    )
}

// MARK: - Int Keys

public extension SettingsKey where Value == Int {
    /// Hour (0–23) for the daily recording reminder. Default: 21 (9 PM).
    static let dailyReminderHour = SettingsKey(rawValue: "dailyReminderHour", defaultValue: 21)
    /// Minute (0–59) for the daily recording reminder. Default: 0.
    static let dailyReminderMinute = SettingsKey(rawValue: "dailyReminderMinute", defaultValue: 0)
    /// Budget warning threshold as an integer percentage (50–90). Default: 80.
    static let budgetWarningThreshold = SettingsKey(rawValue: "budgetWarningThreshold", defaultValue: 80)
}

// MARK: - UserSettingsClient

/// A client interface for type-safe UserDefaults access.
///
/// Use `UserSettingsClient` with `SettingsKey` to read and write
/// UserDefaults values in a testable, dependency-injectable way.
///
/// ```swift
/// @Dependency(\.userSettingsClient) var userSettingsClient
/// let completed = userSettingsClient.bool(.hasCompletedOnboarding)
/// userSettingsClient.setBool(true, .hasCompletedOnboarding)
/// ```
@DependencyClient
public struct UserSettingsClient: Sendable {
    /// Reads a Bool value for the given key, returning `defaultValue` if unset.
    public var bool: @Sendable (_ key: SettingsKey<Bool>) -> Bool = { $0.defaultValue }

    /// Writes a Bool value for the given key.
    public var setBool: @Sendable (_ value: Bool, _ key: SettingsKey<Bool>) -> Void

    /// Reads a String value for the given key, returning `defaultValue` if unset.
    public var string: @Sendable (_ key: SettingsKey<String>) -> String = { $0.defaultValue }

    /// Writes a String value for the given key.
    public var setString: @Sendable (_ value: String, _ key: SettingsKey<String>) -> Void

    /// Reads an Int value for the given key, returning `defaultValue` if unset.
    public var int: @Sendable (_ key: SettingsKey<Int>) -> Int = { $0.defaultValue }

    /// Writes an Int value for the given key.
    public var setInt: @Sendable (_ value: Int, _ key: SettingsKey<Int>) -> Void
}

// MARK: - TestDependencyKey

extension UserSettingsClient: TestDependencyKey {
    public static let testValue = Self(
        bool: { $0.defaultValue },
        setBool: { _, _ in },
        string: { $0.defaultValue },
        setString: { _, _ in },
        int: { $0.defaultValue },
        setInt: { _, _ in }
    )
}

// MARK: - DependencyValues

public extension DependencyValues {
    var userSettingsClient: UserSettingsClient {
        get { self[UserSettingsClient.self] }
        set { self[UserSettingsClient.self] = newValue }
    }
}
