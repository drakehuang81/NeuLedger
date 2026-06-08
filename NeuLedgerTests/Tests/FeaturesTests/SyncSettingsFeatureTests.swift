import ComposableArchitecture
import Domain
import Foundation
import Testing
@testable import Features

@Suite("SyncSettingsFeature Tests")
struct SyncSettingsFeatureTests {

    @Test("task 從 dependencies 載入 isSyncEnabled、isCloudKitAvailable、lastSyncedAt")
    func taskLoadsState() async {
        // 刻意使用與 State 預設值不同的 stub，確保 reducer 真的讀取了依賴
        let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)
        let store = await TestStore(initialState: SyncSettingsFeature.State()) {
            SyncSettingsFeature()
        } withDependencies: {
            $0.platformClient.syncEnabled = { true }       // 預設 false，差異化
            $0.platformClient.syncAvailable = { false }    // 預設 true，差異化
            $0.platformClient.lastSyncedAt = { fixedDate } // 預設 nil，差異化
        }
        await store.send(.task) {
            $0.isSyncEnabled = true
            $0.isCloudKitAvailable = false
            $0.lastSyncedAt = fixedDate
        }
    }

    @Test("enableSyncTapped 串流進度並完成")
    func enableSyncCompletes() async {
        let store = await TestStore(
            initialState: SyncSettingsFeature.State()
        ) {
            SyncSettingsFeature()
        } withDependencies: {
            $0.platformClient.enableSync = {
                AsyncThrowingStream { continuation in
                    continuation.yield(0.5)
                    continuation.yield(1.0)
                    continuation.finish()
                }
            }
            $0.platformClient.lastSyncedAt = { nil }
            $0.continuousClock = ImmediateClock()
        }
        await store.send(.enableSyncTapped) {
            $0.migrationState = .migrating(progress: 0)
        }
        // 寬限 timeout：全 scheme 高載時 effect 派送可能超過預設值（flaky 防治）
        await store.receive(.migrationProgressUpdated(0.5), timeout: .seconds(10)) {
            $0.migrationState = .migrating(progress: 0.5)
        }
        await store.receive(.migrationProgressUpdated(1.0), timeout: .seconds(10)) {
            $0.migrationState = .migrating(progress: 1.0)
        }
        await store.receive(.migrationCompleted, timeout: .seconds(10)) {
            $0.migrationState = .completed
            $0.isSyncEnabled = true
        }
    }

    @Test("syncNowTapped 成功 → isManualSyncing true → receive syncNowFinished → lastSyncedAt 更新")
    func syncNowSuccess() async {
        let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)
        let syncCalled: LockIsolated<Bool> = LockIsolated(false)

        let store = await TestStore(
            initialState: SyncSettingsFeature.State(
                isSyncEnabled: true,
                isCloudKitAvailable: true
            )
        ) {
            SyncSettingsFeature()
        } withDependencies: {
            $0.platformClient.requestSyncNow = { syncCalled.setValue(true) }
            $0.platformClient.lastSyncedAt = { fixedDate }
            $0.continuousClock = ImmediateClock()
        }

        await store.send(.syncNowTapped) {
            $0.isManualSyncing = true
        }

        await store.receive(.syncNowFinished(fixedDate), timeout: .seconds(10)) {
            $0.isManualSyncing = false
            $0.lastSyncedAt = fixedDate
        }

        #expect(syncCalled.value == true, "requestSyncNow 應被呼叫")
    }

    @Test("syncNowTapped 在 isManualSyncing=true 時重入直接 no-op")
    func syncNowReentrancyGuard() async {
        let store = await TestStore(
            initialState: SyncSettingsFeature.State(isManualSyncing: true)
        ) {
            SyncSettingsFeature()
        }

        // 當 isManualSyncing 已為 true，send syncNowTapped 不應產生任何 state 變更或 effect
        await store.send(.syncNowTapped)
    }

    @Test("enableSyncTapped 出錯時顯示 failed 狀態")
    func enableSyncFails() async {
        struct SyncError: Error, LocalizedError {
            var errorDescription: String? { "iCloud not available" }
        }
        let store = await TestStore(
            initialState: SyncSettingsFeature.State()
        ) {
            SyncSettingsFeature()
        } withDependencies: {
            $0.platformClient.enableSync = {
                AsyncThrowingStream { continuation in
                    continuation.finish(throwing: SyncError())
                }
            }
            $0.continuousClock = ImmediateClock()
        }
        await store.send(.enableSyncTapped) {
            $0.migrationState = .migrating(progress: 0)
        }
        // 寬限 timeout：全 scheme 高載時 effect 派送可能超過預設值（flaky 防治）
        await store.receive(.migrationFailed("iCloud not available"), timeout: .seconds(10)) {
            $0.migrationState = .failed("iCloud not available")
        }
    }
}
