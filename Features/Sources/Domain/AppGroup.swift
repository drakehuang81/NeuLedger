import Foundation

/// App Group 線上格式的唯一定義：iPhone app、Core adapter、Watch cache、
/// Widget extension 都從這裡讀。
///
/// **改任何常數都是資料格式變更，需要遷移。** 已安裝的 App 會用舊 key 讀寫，
/// 改名等於讓既有資料讀不到。
public enum AppGroup {
    public static let suiteName = "group.com.drake.NeuLedger"

    /// `WidgetCenter.reloadTimelines(ofKind:)` 用；與
    /// `NeuLedgerWidget/CarrierWidget.swift` 的 `kind` 相同。
    public static let carrierWidgetKind = "CarrierWidget"

    /// 載具 Widget 的 UserDefaults key。
    public enum CarrierKey {
        public static let barcode = "carrierBarcode"        // legacy 單一載具
        public static let type = "carrierType"              // legacy 單一載具
        public static let name = "carrierName"              // legacy 單一載具
        public static let updatedAt = "carrierUpdatedAt"    // legacy 單一載具
        public static let list = "carrierList"              // JSON [CarrierWidgetEntry]

        /// App 內選定「要給 Widget 顯示的載具」（audit A9）。
        ///
        /// 這個 key 是 commit `56a1f4a`（2026-09-26）加的，而本 task 的計劃
        /// 在那之後（09-29）還改過卻沒同步它——計劃全文沒有提到這個 key 一次。
        /// 收斂成單一定義之前，它同時硬寫在 `Shared/WidgetAppGroup.swift` 與
        /// `Core/Adapters/WidgetSyncAdapter+Live.swift`，兩邊靠註解互相提醒。
        /// 連規劃文件都漏掉它，正是那個同步方式的實際成本。
        public static let activeId = "carrierActiveId"
    }
}

/// Widget 端讀取的載具 DTO。JSON 欄位名是既有線上格式，**不可改名**。
public struct CarrierWidgetEntry: Codable, Hashable, Sendable {
    public let id: String            // UUID string（legacy 遷移項為 "legacy"）
    public let barcode: String
    public let typeRawValue: String  // CarrierType.rawValue
    public let name: String
    public let updatedAt: Date?

    public init(id: String, barcode: String, typeRawValue: String, name: String, updatedAt: Date?) {
        self.id = id
        self.barcode = barcode
        self.typeRawValue = typeRawValue
        self.name = name
        self.updatedAt = updatedAt
    }

    public init(carrier: Carrier, updatedAt: Date = Date()) {
        self.init(
            id: carrier.id.uuidString,
            barcode: carrier.barcode,
            typeRawValue: carrier.type.rawValue,
            name: carrier.name,
            updatedAt: updatedAt
        )
    }

    public var type: CarrierType? { CarrierType(rawValue: typeRawValue) }
}
