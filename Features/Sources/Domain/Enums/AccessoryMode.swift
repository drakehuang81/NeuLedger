import Foundation

/// Mode of the floating accessory bar shown above the tab bar.
///
/// Persisted via `UserSettingsAdapter` under the `.accessoryMode`
/// SettingsKey. Two values:
/// - `.add` — quick-add transaction button.
/// - `.ai` — AI assistant (text or voice input).
public enum AccessoryMode: String, Equatable, Sendable, CaseIterable {
    case add
    case ai
}
