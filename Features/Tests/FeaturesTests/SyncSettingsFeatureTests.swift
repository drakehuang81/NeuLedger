import ComposableArchitecture
import Foundation
import Testing
@testable import Features

@Suite("SyncSettingsFeature Tests")
struct SyncSettingsFeatureTests {

    @Test("task 從 dependencies 載入 isSubscribed、isSyncEnabled、isCloudKitAvailable")
    func taskLoadsState() async {
        let store = await TestStore(initialState: SyncSettingsFeature.State()) {
            SyncSettingsFeature()
        } withDependencies: {
            $0.userSettingsClient.bool = { key in
                switch key.rawValue {
                case "isSubscribed": return true
                case "isSyncEnabled": return false
                default: return key.defaultValue
                }
            }
            $0.syncClient.isCloudKitAvailable = { true }
        }
        await store.send(.task) {
            $0.isSubscribed = true
            $0.isSyncEnabled = false
            $0.isCloudKitAvailable = true
        }
    }

    @Test("subscribeNowTapped 設定 isSubscribed 為 true 並儲存至 settings")
    func subscribeNowPersists() async {
        let stored = LockIsolated<[String: Bool]>([:])
        let store = await TestStore(initialState: SyncSettingsFeature.State()) {
            SyncSettingsFeature()
        } withDependencies: {
            $0.userSettingsClient.bool = { _ in false }
            $0.userSettingsClient.setBool = { value, key in stored.withValue { $0[key.rawValue] = value } }
            $0.syncClient.isCloudKitAvailable = { false }
        }
        await store.send(.subscribeNowTapped) {
            $0.isSubscribed = true
        }
        #expect(stored.value["isSubscribed"] == true)
    }

    @Test("enableSyncTapped 串流進度並完成")
    func enableSyncCompletes() async {
        let store = await TestStore(
            initialState: SyncSettingsFeature.State(isSubscribed: true)
        ) {
            SyncSettingsFeature()
        } withDependencies: {
            $0.syncClient.enableSync = {
                AsyncThrowingStream { continuation in
                    continuation.yield(0.5)
                    continuation.yield(1.0)
                    continuation.finish()
                }
            }
            $0.userSettingsClient.bool = { _ in false }
            $0.userSettingsClient.setBool = { _, _ in }
        }
        await store.send(.enableSyncTapped) {
            $0.migrationState = .migrating(progress: 0)
        }
        await store.receive(.migrationProgressUpdated(0.5)) {
            $0.migrationState = .migrating(progress: 0.5)
        }
        await store.receive(.migrationProgressUpdated(1.0)) {
            $0.migrationState = .migrating(progress: 1.0)
        }
        await store.receive(.migrationCompleted) {
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
            initialState: SyncSettingsFeature.State(isSubscribed: true)
        ) {
            SyncSettingsFeature()
        } withDependencies: {
            $0.syncClient.enableSync = {
                AsyncThrowingStream { continuation in
                    continuation.finish(throwing: SyncError())
                }
            }
            $0.userSettingsClient.bool = { _ in false }
        }
        await store.send(.enableSyncTapped) {
            $0.migrationState = .migrating(progress: 0)
        }
        await store.receive(.migrationFailed("iCloud not available")) {
            $0.migrationState = .failed("iCloud not available")
        }
    }
}
