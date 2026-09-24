import Foundation
import ComposableArchitecture
import Domain

@Reducer
struct MainTabFeature {
    // MARK: - State
    enum Tab: String, CaseIterable, Equatable {
        case dashboard
        case settings
        case transactions
    }

    @ObservableState
    struct State: Equatable {
        var selectedTab: Tab = .dashboard
        var dashboard = DashboardFeature.State()
        var transactions = TransactionsFeature.State()
        var settings = SettingsFeature.State()

        // Floating accessory bar (AI input / quick-add)
        var accessory = AccessoryBarFeature.State()

        // Accessory bar visibility — depends on tab + child nav, so it stays here.
        var showAccessoryBar: Bool = true

        var isAccessoryVisible: Bool {
            guard showAccessoryBar else { return false }
            switch selectedTab {
            case .settings:     return settings.path.isEmpty
            case .dashboard:    return dashboard.path.isEmpty
            case .transactions: return true
            }
        }
    }

    // MARK: - Action
    enum Action: Equatable {
        case tabSelected(Tab)

        // Lifecycle
        case task
        case accessoryBarVisibilityLoaded(Bool)

        /// App 回到前景（由 MainTabView 的 scenePhase 送出）。
        case scenePhaseBecameActive
        /// 跑一次週期交易補記。
        case recurringTickRequested
        /// 補記完成，附帶實際記了幾筆。
        case recurringTicked(Int)
        /// 補記失敗；沒有 UI 承接，下次進前景會自動重試（plan R6）。
        case recurringTickFailed(String)

        case accessory(AccessoryBarFeature.Action)
        case dashboard(DashboardFeature.Action)
        case transactions(TransactionsFeature.Action)
        case settings(SettingsFeature.Action)
    }

    // MARK: - Dependencies
    @Dependency(\.platformClient) var platformClient
    @Dependency(\.ledgerClient) var ledger

    private enum CancelID {
        case task
        case recurringTick
    }

    // MARK: - Body
    var body: some ReducerOf<Self> {
        Scope(state: \.accessory, action: \.accessory) {
            AccessoryBarFeature()
        }
        Scope(state: \.dashboard, action: \.dashboard) {
            DashboardFeature()
        }
        Scope(state: \.transactions, action: \.transactions) {
            TransactionsFeature()
        }
        Scope(state: \.settings, action: \.settings) {
            SettingsFeature()
        }
        Reduce { state, action in
            switch action {
            case .task:
                // Forward to the accessory bar's own load (availability + mode) when MainTabView appears,
                // so it runs regardless of whether the accessory is currently visible.
                return .merge(
                    .run { send in
                        await send(.accessory(.task))
                        let showAccessoryBar = platformClient.showAccessoryBar()
                        await send(.accessoryBarVisibilityLoaded(showAccessoryBar))
                    }
                    .cancellable(id: CancelID.task),
                    .send(.recurringTickRequested)
                )

            case let .accessoryBarVisibilityLoaded(visible):
                state.showAccessoryBar = visible
                return .none

            case .scenePhaseBecameActive:
                return .send(.recurringTickRequested)

            case .recurringTickRequested:
                // 週期交易的唯一推進點（health-audit A2：tick 原本零呼叫點）。
                // cancelInFlight：啟動時的 .task 與回前景可能連續觸發，只留最後一次。
                return .run { send in
                    let count = try await ledger.tick()
                    await send(.recurringTicked(count))
                } catch: { error, send in
                    await send(.recurringTickFailed(error.localizedDescription))
                }
                .cancellable(id: CancelID.recurringTick, cancelInFlight: true)

            case let .recurringTicked(count):
                // 沒補記到東西就不用多打一輪查詢（plan R8）。
                guard count > 0 else { return .none }
                return .merge(
                    .send(.dashboard(.pulledToRefresh)),
                    .send(.transactions(.task))
                )

            case .recurringTickFailed:
                // 刻意不顯示：MainTab 沒有自己的 UI 可以承接，且下次進前景就會重試（plan R6）。
                return .none

            case let .tabSelected(tab):
                state.selectedTab = tab
                return .none

            // MARK: Accessory routing (depends on selectedTab — a tab-shell concern)
            case .accessory(.delegate(.contextActionRequested)):
                switch state.selectedTab {
                case .transactions:
                    return .send(.transactions(.contextActionTapped))
                default:
                    return .send(.dashboard(.addTransactionButtonTapped))
                }

            case let .accessory(.delegate(.transactionExtracted(extracted))):
                switch state.selectedTab {
                case .transactions:
                    return .send(.transactions(.addTransactionWithPrefilledData(extracted)))
                default:
                    return .send(.dashboard(.addTransactionWithPrefilledData(extracted)))
                }

            case .accessory:
                return .none

            // MARK: Child delegates
            case .dashboard(.delegate(.seeAllTransactionsTapped)):
                state.selectedTab = .transactions
                return .none

            case .dashboard:
                return .none

            case .transactions:
                return .none

            case let .settings(.delegate(.accessoryBarVisibilityChanged(visible))):
                state.showAccessoryBar = visible
                return .none

            case .settings:
                return .none
            }
        }
    }
}
