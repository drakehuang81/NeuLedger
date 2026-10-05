// Shared/WidgetAppGroup.swift
import Domain
import Foundation

/// App Group 的讀取端（Widget Extension 與主 app 共同編譯）。
///
/// 常數與 DTO 的唯一來源是 `Domain/AppGroup.swift`；主 app 是唯一寫入者
/// （`Core/Adapters/WidgetSyncAdapter+Live.swift`）。
///
/// 這個檔案原本自己宣告 `suiteName`、一組 `Key` enum、以及一份
/// `struct CarrierEntry`，與 Core 那邊的複本靠註解互相提醒同步。現在
/// `NeuLedgerWidget` target 連結了 Domain（pbxproj 的
/// `packageProductDependencies`），所以兩邊能共用同一份定義。
typealias CarrierEntry = CarrierWidgetEntry

extension CarrierWidgetEntry {
    /// Widget 顯示用的載具類型名稱。
    ///
    /// 原本這裡是第三份 `typeRawValue` 的 switch，而且它呼叫
    /// `String(localized:)` 時沒帶 `bundle: .main`。改走 Domain 的
    /// `CarrierType.localizedName`（它有帶），`carrier_type_*` 的翻譯因此
    /// 統一由那一處負責——Widget 的字串表本來就有這兩個 key。
    var typeDisplayName: String {
        type?.localizedName ?? typeRawValue
    }
}

enum WidgetAppGroup {
    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: AppGroup.suiteName)
    }

    // MARK: - Legacy single-carrier read (kept for compat)

    /// Reads the legacy single carrier configuration from App Group.
    /// Returns `nil` if no carrier is configured or data is inconsistent.
    static func readCarrier() -> CarrierEntry? {
        guard let defaults,
              let barcode = defaults.string(forKey: AppGroup.CarrierKey.barcode),
              !barcode.isEmpty,
              let typeRaw = defaults.string(forKey: AppGroup.CarrierKey.type),
              !typeRaw.isEmpty else {
            return nil
        }
        let name = defaults.string(forKey: AppGroup.CarrierKey.name) ?? ""
        let updatedAt = defaults.object(forKey: AppGroup.CarrierKey.updatedAt) as? Date
        // Legacy entry has no ID — use a deterministic placeholder so callers can
        // still identify it; new code should prefer readAllCarriers().
        return CarrierEntry(
            id: "legacy",
            barcode: barcode,
            typeRawValue: typeRaw,
            name: name,
            updatedAt: updatedAt
        )
    }

    // MARK: - Full carrier list read

    static func readAllCarriers() -> [CarrierEntry] {
        guard let defaults,
              let data = defaults.data(forKey: AppGroup.CarrierKey.list) else {
            return []
        }
        return (try? JSONDecoder().decode([CarrierEntry].self, from: data)) ?? []
    }

    // MARK: - Active carrier for widget (audit A9)

    /// The carrier the user picked in-app for the widget to show.
    /// `nil` when the user has never chosen one.
    ///
    /// 這一顆是 commit `56a1f4a` 加的，而本次收斂的計劃沒有涵蓋它——計劃的
    /// 整檔改寫只列了 `readCarrier` 與 `readAllCarriers`。照抄會刪掉它，而
    /// `NeuLedgerWidget/CarrierWidget.swift` 有在呼叫，Widget 會編不過。
    static func readActiveCarrierId() -> String? {
        guard let defaults,
              let id = defaults.string(forKey: AppGroup.CarrierKey.activeId),
              !id.isEmpty else {
            return nil
        }
        return id
    }
}
