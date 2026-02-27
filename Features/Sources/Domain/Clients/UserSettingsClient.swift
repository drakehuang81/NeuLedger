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
}

// MARK: - TestDependencyKey

extension UserSettingsClient: TestDependencyKey {
    public static let testValue = Self(
        bool: { $0.defaultValue },
        setBool: { _, _ in }
    )
}

// MARK: - DependencyValues

public extension DependencyValues {
    var userSettingsClient: UserSettingsClient {
        get { self[UserSettingsClient.self] }
        set { self[UserSettingsClient.self] = newValue }
    }
}
