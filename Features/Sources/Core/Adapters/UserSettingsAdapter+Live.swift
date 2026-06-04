import Foundation
import Domain
import Dependencies

/// Live implementation of `UserSettingsAdapter` backed by `UserDefaults.standard`.
extension UserSettingsAdapter: DependencyKey {
    public static var liveValue: UserSettingsAdapter {
        UserSettingsAdapter(
            bool: { key in
                if UserDefaults.standard.object(forKey: key.rawValue) != nil {
                    return UserDefaults.standard.bool(forKey: key.rawValue)
                }
                return key.defaultValue
            },
            setBool: { value, key in
                UserDefaults.standard.set(value, forKey: key.rawValue)
            },
            string: { key in
                UserDefaults.standard.string(forKey: key.rawValue) ?? key.defaultValue
            },
            setString: { value, key in
                UserDefaults.standard.set(value, forKey: key.rawValue)
            },
            int: { key in
                if UserDefaults.standard.object(forKey: key.rawValue) != nil {
                    return UserDefaults.standard.integer(forKey: key.rawValue)
                }
                return key.defaultValue
            },
            setInt: { value, key in
                UserDefaults.standard.set(value, forKey: key.rawValue)
            },
            date: { key in
                UserDefaults.standard.object(forKey: key.rawValue) as? Date ?? key.defaultValue
            },
            setDate: { value, key in
                if let value {
                    UserDefaults.standard.set(value, forKey: key.rawValue)
                } else {
                    UserDefaults.standard.removeObject(forKey: key.rawValue)
                }
            }
        )
    }
}
