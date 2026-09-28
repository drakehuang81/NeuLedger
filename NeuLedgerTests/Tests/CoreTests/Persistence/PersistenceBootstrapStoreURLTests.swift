import Testing
import Foundation
import SwiftData
@testable import Core

/// 釘住「測試永遠碰不到真實 store」這個機制。
///
/// 背景：`NeuLedgerTests` 由 `NeuLedger.app` 承載，因此繼承
/// `group.com.drake.NeuLedger` 這個 App Group 權限——所以 App Group 裡的
/// `default.store` 就是**已安裝 App 正在用的那一顆**。資料完整性 PR 期間，
/// 一條端到端的 wipe 測試因此真的抹除了模擬器上使用者的帳本，而且是在
/// **通過**的情況下做的。移除那條測試只修掉了那一個呼叫者；這組測試釘住的是
/// 機制，讓下一個呼叫破壞性持久層路徑的測試無法再碰到真實資料。
@Suite("PersistenceBootstrap store URL — 測試不得指向真實 App Group store")
struct PersistenceBootstrapStoreURLTests {

    /// App Group 容器的路徑（若權限存在）。測試中的 store 絕不能落在它底下。
    private var appGroupContainer: URL? {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.drake.NeuLedger"
        )
    }

    @Test("本地設定的 store 不在 App Group 容器底下")
    func localConfigurationIsNotInTheAppGroup() throws {
        let storeURL = PersistenceBootstrap.localConfiguration.url
        // 這個斷言只有在權限確實存在時才有意義——而它存在正是問題所在，
        // 所以先確認前提，否則這條測試會真空通過。
        let group = try #require(
            appGroupContainer,
            "測試 host 應該繼承 App Group 權限；若這裡是 nil，這條測試就失去意義，需要重新檢查 target 設定"
        )
        #expect(
            !storeURL.path().hasPrefix(group.path()),
            "測試時的 store 落在 App Group 容器底下（\(storeURL.path())），那就是已安裝 App 正在用的同一顆資料庫"
        )
    }

    @Test("CloudKit 設定與本地設定指向同一顆（重導不得只改一半）")
    func bothConfigurationsPointAtTheSameRedirectedStore() {
        #expect(
            PersistenceBootstrap.localConfiguration.url == PersistenceBootstrap.cloudConfiguration.url,
            "兩個設定必須共用同一個 store URL，否則切換同步會搬檔案——重導若只套用到其中一個，這個不變量會斷"
        )
    }

    @Test("重導後的路徑在暫存目錄底下，且帶 process 區隔")
    func redirectedPathIsUnderTemporaryDirectory() {
        let storeURL = PersistenceBootstrap.localConfiguration.url
        #expect(storeURL.path().hasPrefix(URL.temporaryDirectory.path()))
        #expect(storeURL.path().contains("NeuLedgerTests-"))
    }
}
