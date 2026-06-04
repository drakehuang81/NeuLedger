import ComposableArchitecture
import Domain
import Foundation
import Testing
@testable import Features

@Suite("SyncSettingsFeature Tests")
struct SyncSettingsFeatureTests {

    @Test("task 從 dependencies 載入 isSyncEnabled、isCloudKitAvailable")
    func taskLoadsState() async {
        let store = await TestStore(initialState: SyncSettingsFeature.State()) {
            SyncSettingsFeature()
        } withDependencies: {
            $0.platformClient.syncEnabled = { false }
            $0.platformClient.syncAvailable = { true }
            $0.platformClient.lastSyncedAt = { nil }
        }
        await store.send(.task)
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
