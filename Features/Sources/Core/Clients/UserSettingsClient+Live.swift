import Foundation
import Domain
import Dependencies

/// Live implementation of `UserSettingsClient` backed by `UserDefaults.standard`.
extension UserSettingsClient: DependencyKey {
    public static var liveValue: UserSettingsClient {
        UserSettingsClient(
            bool: { key in
                if UserDefaults.standard.object(forKey: key.rawValue) != nil {
                    return UserDefaults.standard.bool(forKey: key.rawValue)
                }
                return key.defaultValue
            },
            setBool: { value, key in
                UserDefaults.standard.set(value, forKey: key.rawValue)
            }
        )
    }
}
