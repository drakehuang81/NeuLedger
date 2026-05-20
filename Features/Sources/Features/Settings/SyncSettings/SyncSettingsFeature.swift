import ComposableArchitecture
import Domain
import Foundation

@Reducer
public struct SyncSettingsFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var isSyncEnabled: Bool = false
        public var isCloudKitAvailable: Bool = true
        public var migrationState: MigrationState = .idle
        public var lastSyncedAt: Date?
        public var isManualSyncing: Bool = false

        public enum MigrationState: Equatable {
            case idle
            case migrating(progress: Double)
            case completed
            case failed(String)
        }

        public init(
            isSyncEnabled: Bool = false,
            isCloudKitAvailable: Bool = true,
            migrationState: MigrationState = .idle,
            lastSyncedAt: Date? = nil,
            isManualSyncing: Bool = false
        ) {
            self.isSyncEnabled = isSyncEnabled
            self.isCloudKitAvailable = isCloudKitAvailable
            self.migrationState = migrationState
            self.lastSyncedAt = lastSyncedAt
            self.isManualSyncing = isManualSyncing
        }
    }

    public enum Action: Equatable {
        case task
        case enableSyncTapped
        case migrationProgressUpdated(Double)
        case migrationCompleted
        case migrationFailed(String)
        case syncNowTapped
        case syncNowFinished(Date)
    }

    @Dependency(\.syncClient) var syncClient
    @Dependency(\.userSettingsClient) var userSettingsClient
    @Dependency(\.continuousClock) var clock

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                state.isSyncEnabled = userSettingsClient.bool(.isSyncEnabled)
                state.isCloudKitAvailable = syncClient.isCloudKitAvailable()
                state.lastSyncedAt = syncClient.lastSyncedAt()
                return .none

            case .enableSyncTapped:
                state.migrationState = .migrating(progress: 0)
                return .run { [clock] send in
                    let start = Date()
                    let minimum: TimeInterval = 1.0
                    func padIfNeeded() async {
                        let remaining = minimum - Date().timeIntervalSince(start)
                        if remaining > 0 {
                            try? await clock.sleep(for: .seconds(remaining))
                        }
                    }
                    do {
                        for try await progress in syncClient.enableSync() {
                            await send(.migrationProgressUpdated(progress))
                        }
                        await padIfNeeded()
                        await send(.migrationCompleted)
                    } catch {
                        await padIfNeeded()
                        await send(.migrationFailed(error.localizedDescription))
                    }
                }

            case .migrationProgressUpdated(let progress):
                state.migrationState = .migrating(progress: progress)
                return .none

            case .migrationCompleted:
                state.migrationState = .completed
                state.isSyncEnabled = true
                state.lastSyncedAt = syncClient.lastSyncedAt()
                return .none

            case .migrationFailed(let message):
                state.migrationState = .failed(message)
                return .none

            case .syncNowTapped:
                guard !state.isManualSyncing else { return .none }
                state.isManualSyncing = true
                return .run { [clock] send in
                    let start = Date()
                    try? await syncClient.requestSyncNow()
                    let remaining = 1.0 - Date().timeIntervalSince(start)
                    if remaining > 0 {
                        try? await clock.sleep(for: .seconds(remaining))
                    }
                    await send(.syncNowFinished(syncClient.lastSyncedAt() ?? Date()))
                }

            case let .syncNowFinished(date):
                state.isManualSyncing = false
                state.lastSyncedAt = date
                return .none
            }
        }
    }
}
