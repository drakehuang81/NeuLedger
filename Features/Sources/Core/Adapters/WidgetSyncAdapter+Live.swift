import Foundation
import WidgetKit
import Dependencies
import Domain

/// App Group 的 suite name、key 與 DTO 的唯一來源是 `Domain/AppGroup.swift`；
/// 這裡只負責寫入與觸發 Widget 重載。
///
/// 這個檔案原本自己複製了一份常數與 `CarrierEntryDTO`，靠一行
/// `MUST stay in sync with Shared/WidgetAppGroup.swift` 的註解維持一致——
/// 而 commit `56a1f4a` 新增 `carrierActiveId` 時確實得同時改六個檔案才對得上。
extension WidgetSyncAdapter: DependencyKey {

    public static let liveValue = live(
        defaults: { UserDefaults(suiteName: AppGroup.suiteName) },
        reload: { WidgetCenter.shared.reloadTimelines(ofKind: AppGroup.carrierWidgetKind) }
    )

    /// 可注入 `defaults` 與 `reload` 的工廠。
    ///
    /// `liveValue` 直接寫 App Group 的真實 suite 並呼叫 `WidgetCenter`，兩者在
    /// 測試裡都不可用——前者會污染這台機器上與已安裝 App 共用的 defaults，
    /// 後者在測試行程裡沒有 widget host。把這兩個出口變成參數之後，寫入的
    /// key 與 payload 格式才測得到，而那個格式正是改了就會讓舊版 Widget
    /// 讀不到資料的部分。
    static func live(
        defaults defaultsProvider: @escaping @Sendable () -> UserDefaults?,
        reload: @escaping @Sendable () -> Void
    ) -> Self {
        Self(
            syncCarrier: { barcode, type, name in
                guard let defaults = defaultsProvider() else { return }
                defaults.set(barcode, forKey: AppGroup.CarrierKey.barcode)
                defaults.set(type,    forKey: AppGroup.CarrierKey.type)
                defaults.set(name,    forKey: AppGroup.CarrierKey.name)
                defaults.set(Date(),  forKey: AppGroup.CarrierKey.updatedAt)
                reload()
            },
            clearCarrier: {
                guard let defaults = defaultsProvider() else { return }
                for key in [
                    AppGroup.CarrierKey.barcode,
                    AppGroup.CarrierKey.type,
                    AppGroup.CarrierKey.name,
                    AppGroup.CarrierKey.updatedAt,
                ] {
                    defaults.removeObject(forKey: key)
                }
                reload()
            },
            syncAllCarriers: { carriers in
                guard let defaults = defaultsProvider() else { return }
                // `updatedAt` 刻意是「同步時間」而非載具的更新時間：`Carrier`
                // entity 只有 `createdAt`，沒有可傳的 updatedAt。這與收斂前的
                // 行為相同。
                let entries = carriers.map { CarrierWidgetEntry(carrier: $0) }
                guard let data = try? JSONEncoder().encode(entries) else { return }
                defaults.set(data, forKey: AppGroup.CarrierKey.list)
                reload()
            },
            setActiveCarrierId: { id in
                guard let defaults = defaultsProvider() else { return }
                defaults.set(id, forKey: AppGroup.CarrierKey.activeId)
                reload()
            }
        )
    }
}
