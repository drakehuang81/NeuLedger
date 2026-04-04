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

        public enum MigrationState: Equatable {
            case idle
            case migrating(progress: Double)
            case completed
            case failed(String)
        }

        public init(
            isSyncEnabled: Bool = false,
            isCloudKitAvailable: Bool = true,
            migrationState: MigrationState = .idle
        ) {
            self.isSyncEnabled = isSyncEnabled
            self.isCloudKitAvailable = isCloudKitAvailable
            self.migrationState = migrationState
        }
    }

    public enum Action: Equatable {
        case task
        case enableSyncTapped
        case migrationProgressUpdated(Double)
        case migrationCompleted
        case migrationFailed(String)
    }

    @Dependency(\.syncClient) var syncClient
    @Dependency(\.userSettingsClient) var userSettingsClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                state.isSyncEnabled = userSettingsClient.bool(.isSyncEnabled)
                state.isCloudKitAvailable = syncClient.isCloudKitAvailable()
                return .none

            case .enableSyncTapped:
                state.migrationState = .migrating(progress: 0)
                return .run { send in
                    for try await progress in syncClient.enableSync() {
                        await send(.migrationProgressUpdated(progress))
                    }
                    await send(.migrationCompleted)
                } catch: { error, send in
                    await send(.migrationFailed(error.localizedDescription))
                }

            case .migrationProgressUpdated(let progress):
                state.migrationState = .migrating(progress: progress)
                return .none

            case .migrationCompleted:
                state.migrationState = .completed
                state.isSyncEnabled = true
                return .none

            case .migrationFailed(let message):
                state.migrationState = .failed(message)
                return .none
            }
        }
    }
}
