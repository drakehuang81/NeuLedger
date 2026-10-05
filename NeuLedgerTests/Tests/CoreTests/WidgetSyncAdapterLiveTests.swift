import Foundation
import Testing
import Domain
import ConcurrencyExtras
@testable import Core

/// `WidgetSyncAdapter` 的寫入端測試。
///
/// 測得到的前提是 `live(defaults:reload:)` 這個工廠：`liveValue` 會寫真正的
/// App Group suite（污染這台機器上與已安裝 App 共用的 defaults）並呼叫
/// `WidgetCenter`（測試行程沒有 widget host）。
///
/// 驗的是**寫入的 key 與 payload 格式**——那正是改了之後舊版 Widget 會讀不到
/// 資料的部分，而收斂前這段格式散在三個檔案裡靠註解同步。
@Suite("WidgetSyncAdapter Live")
struct WidgetSyncAdapterLiveTests {

    private func makeSUT() -> (WidgetSyncAdapter, UserDefaults, LockIsolated<Int>) {
        let suite = "WidgetSyncAdapterLiveTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let reloads = LockIsolated(0)
        // closure 裡用 suite name 重建而不是捕捉 `defaults`：`UserDefaults`
        // 不是 `Sendable`，捕捉它在 `@Sendable` closure 裡編不過。同一個
        // suite name 取得的實例共享同一份資料，所以下面的讀取驗證照樣成立，
        // 而且這更接近 `liveValue` 的實際行為——它也是在 closure 內才建。
        let sut = WidgetSyncAdapter.live(
            defaults: { UserDefaults(suiteName: suite) },
            reload: { reloads.withValue { $0 += 1 } }
        )
        return (sut, defaults, reloads)
    }

    @Test("syncAllCarriers writes [CarrierWidgetEntry] under CarrierKey.list and reloads")
    func syncAll() async throws {
        let (sut, defaults, reloads) = makeSUT()
        let carrier = Carrier(name: "A", type: .citizenDigitalCertificate, barcode: "/P0123456789ABCDEF")

        await sut.syncAllCarriers([carrier])

        let data = try #require(defaults.data(forKey: AppGroup.CarrierKey.list))
        let entries = try JSONDecoder().decode([CarrierWidgetEntry].self, from: data)
        #expect(entries.count == 1)
        #expect(entries.first?.id == carrier.id.uuidString)
        #expect(entries.first?.typeRawValue == "citizenDigitalCertificate")
        #expect(entries.first?.barcode == "/P0123456789ABCDEF")
        #expect(reloads.value == 1)
    }

    @Test("syncCarrier writes the four legacy keys and reloads")
    func syncLegacy() async {
        let (sut, defaults, reloads) = makeSUT()

        await sut.syncCarrier("/ABC1234", "phoneBarcodeCarrier", "手機條碼")

        #expect(defaults.string(forKey: AppGroup.CarrierKey.barcode) == "/ABC1234")
        #expect(defaults.string(forKey: AppGroup.CarrierKey.type) == "phoneBarcodeCarrier")
        #expect(defaults.string(forKey: AppGroup.CarrierKey.name) == "手機條碼")
        #expect(defaults.object(forKey: AppGroup.CarrierKey.updatedAt) is Date)
        #expect(reloads.value == 1)
    }

    @Test("clearCarrier removes the legacy keys but leaves the list alone")
    func clearLeavesList() async throws {
        let (sut, defaults, reloads) = makeSUT()
        await sut.syncCarrier("/ABC1234", "phoneBarcodeCarrier", "手機條碼")
        await sut.syncAllCarriers([Carrier(name: "A", type: .phoneBarcodeCarrier, barcode: "/A")])

        await sut.clearCarrier()

        #expect(defaults.string(forKey: AppGroup.CarrierKey.barcode) == nil)
        #expect(defaults.string(forKey: AppGroup.CarrierKey.type) == nil)
        #expect(defaults.string(forKey: AppGroup.CarrierKey.name) == nil)
        #expect(defaults.object(forKey: AppGroup.CarrierKey.updatedAt) == nil)
        // `clearCarrier` 只清 legacy 單一載具那四顆；列表是另一條路徑寫的，
        // 清掉它會讓 Widget 的載具選單整個空掉。
        #expect(defaults.data(forKey: AppGroup.CarrierKey.list) != nil)
        #expect(reloads.value == 3)
    }

    @Test("setActiveCarrierId writes under CarrierKey.activeId")
    func setActive() async {
        let (sut, defaults, reloads) = makeSUT()

        await sut.setActiveCarrierId("the-id")

        #expect(defaults.string(forKey: AppGroup.CarrierKey.activeId) == "the-id")
        #expect(reloads.value == 1)
    }
}
