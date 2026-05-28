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
            $0.userSettingsRepository.bool = { key in
                switch key.rawValue {
                case "isSyncEnabled": return false
                default: return key.defaultValue
                }
            }
            $0.cloudSyncUseCase.isAvailable = { true }
            $0.cloudSyncUseCase.lastSyncedAt = { nil }
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
            $0.cloudSyncUseCase.enable = {
                AsyncThrowingStream { continuation in
                    continuation.yield(0.5)
                    continuation.yield(1.0)
                    continuation.finish()
                }
            }
            $0.userSettingsRepository.bool = { _ in false }
            $0.userSettingsRepository.setBool = { _, _ in }
            $0.cloudSyncUseCase.lastSyncedAt = { nil }
            $0.continuousClock = ImmediateClock()
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
            initialState: SyncSettingsFeature.State()
        ) {
            SyncSettingsFeature()
        } withDependencies: {
            $0.cloudSyncUseCase.enable = {
                AsyncThrowingStream { continuation in
                    continuation.finish(throwing: SyncError())
                }
            }
            $0.userSettingsRepository.bool = { _ in false }
            $0.continuousClock = ImmediateClock()
        }
        await store.send(.enableSyncTapped) {
            $0.migrationState = .migrating(progress: 0)
        }
        await store.receive(.migrationFailed("iCloud not available")) {
            $0.migrationState = .failed("iCloud not available")
        }
    }
}
