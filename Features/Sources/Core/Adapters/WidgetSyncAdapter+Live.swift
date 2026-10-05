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

    public static let liveValue = Self(
        syncCarrier: { barcode, type, name in
            guard let defaults = UserDefaults(suiteName: AppGroup.suiteName) else { return }
            defaults.set(barcode, forKey: AppGroup.CarrierKey.barcode)
            defaults.set(type,    forKey: AppGroup.CarrierKey.type)
            defaults.set(name,    forKey: AppGroup.CarrierKey.name)
            defaults.set(Date(),  forKey: AppGroup.CarrierKey.updatedAt)
            WidgetCenter.shared.reloadTimelines(ofKind: AppGroup.carrierWidgetKind)
        },
        clearCarrier: {
            guard let defaults = UserDefaults(suiteName: AppGroup.suiteName) else { return }
            for key in [
                AppGroup.CarrierKey.barcode,
                AppGroup.CarrierKey.type,
                AppGroup.CarrierKey.name,
                AppGroup.CarrierKey.updatedAt,
            ] {
                defaults.removeObject(forKey: key)
            }
            WidgetCenter.shared.reloadTimelines(ofKind: AppGroup.carrierWidgetKind)
        },
        syncAllCarriers: { carriers in
            guard let defaults = UserDefaults(suiteName: AppGroup.suiteName) else { return }
            // `updatedAt` 刻意是「同步時間」而非載具的更新時間：`Carrier` entity
            // 只有 `createdAt`，沒有可傳的 updatedAt。這與收斂前的行為相同。
            let entries = carriers.map { CarrierWidgetEntry(carrier: $0) }
            guard let data = try? JSONEncoder().encode(entries) else { return }
            defaults.set(data, forKey: AppGroup.CarrierKey.list)
            WidgetCenter.shared.reloadTimelines(ofKind: AppGroup.carrierWidgetKind)
        },
        setActiveCarrierId: { id in
            guard let defaults = UserDefaults(suiteName: AppGroup.suiteName) else { return }
            defaults.set(id, forKey: AppGroup.CarrierKey.activeId)
            WidgetCenter.shared.reloadTimelines(ofKind: AppGroup.carrierWidgetKind)
        }
    )
}
