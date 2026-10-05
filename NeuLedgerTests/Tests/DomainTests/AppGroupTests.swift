import Foundation
import Testing
@testable import Domain

/// 釘住 App Group 的線上格式：suite 名稱、key 名稱、DTO 欄位。
///
/// 改任何一個都是資料格式變更——已安裝的 App 用舊 key 讀寫，舊版 Widget 會
/// 讀不到。這個 suite 的作用不是「驗證實作正確」，而是讓那種改動必須先讓
/// 測試變紅、無法順手帶過。
@Suite("AppGroup constants")
struct AppGroupTests {
    @Test("suite name and widget kind are stable")
    func constants() {
        #expect(AppGroup.suiteName == "group.com.drake.NeuLedger")
        #expect(AppGroup.carrierWidgetKind == "CarrierWidget")
        #expect(AppGroup.CarrierKey.barcode == "carrierBarcode")
        #expect(AppGroup.CarrierKey.type == "carrierType")
        #expect(AppGroup.CarrierKey.name == "carrierName")
        #expect(AppGroup.CarrierKey.updatedAt == "carrierUpdatedAt")
        #expect(AppGroup.CarrierKey.list == "carrierList")
        // 計劃的 `CarrierKey` 定義漏了這一顆（commit `56a1f4a` 加的），所以
        // 它也不在計劃給的這條測試裡。`CarrierWidget.swift` 讀它來決定要顯示
        // 哪一張載具。
        #expect(AppGroup.CarrierKey.activeId == "carrierActiveId")
    }

    @Test("CarrierWidgetEntry JSON keys match the legacy wire format")
    func wireFormat() throws {
        let carrier = Carrier(name: "我的載具", type: .phoneBarcodeCarrier, barcode: "/ABC1234")
        let entry = CarrierWidgetEntry(carrier: carrier, updatedAt: Date(timeIntervalSince1970: 0))
        let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(entry)) as! [String: Any]
        #expect(Set(json.keys) == ["id", "barcode", "typeRawValue", "name", "updatedAt"])
        #expect(json["id"] as? String == carrier.id.uuidString)
        #expect(json["typeRawValue"] as? String == "phoneBarcodeCarrier")
        #expect(entry.type == .phoneBarcodeCarrier)
    }

    @Test("an unknown typeRawValue decodes without crashing and reports nil type")
    func unknownTypeIsTolerated() throws {
        // 舊版寫入、新版讀取時可能遇到未知的 rawValue；`type` 是 optional 正是
        // 為此，而 `Shared/WidgetAppGroup.swift` 的 `typeDisplayName` 會退回
        // 顯示 rawValue 本身而不是崩掉。
        let json = #"{"id":"x","barcode":"/A","typeRawValue":"futureType","name":"n","updatedAt":null}"#
        let entry = try JSONDecoder().decode(CarrierWidgetEntry.self, from: Data(json.utf8))
        #expect(entry.type == nil)
        #expect(entry.typeRawValue == "futureType")
    }
}
