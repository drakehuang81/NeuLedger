import Testing
import ComposableArchitecture
import Foundation
@testable import Features
import Domain

/// 補測試：refreshAfterMutation 統一重載的三個入口
///
/// 每個入口都會 merge 四條 effect：
///   accountsEffect → accountsUpdated（→ accountBalancesComputed）
///   transactionsEffect → transactionsUpdated
///   statsEffect → statsComputed
///   sparklineEffect → weeklySpendingComputed
///
/// 測試策略：
///  - exhaustivity = .off
///  - 直接在 initial state 放子 feature state（不送 addTransactionButtonTapped，
///    避免 AddTransactionFeature.task 的 in-flight 副作用干擾）
///  - send presented delegate → skipReceivedActions（等待所有 effects 完成並跳過）
///  - 斷言最終 state 的 section phase 全部為 loaded
@Suite("DashboardFeature refreshAfterMutation")
struct DashboardFeatureMutationTests {

    // MARK: - 共用樣本資料

    private static let sampleAccount = Account(
        id: "00000000-0000-0000-0000-000000000001",
        name: "現金", type: .cash, icon: "banknote", color: "#34C759"
    )
    private static let sampleTransaction = Transaction(
        amount: 200, date: Date(timeIntervalSince1970: 1_000_000),
        note: "午餐", accountId: "00000000-0000-0000-0000-000000000001",
        type: .expense
    )

    // MARK: - 共用 stub 組合

    @MainActor
    private func makeStore(
        initial: DashboardFeature.State = DashboardFeature.State()
    ) async -> TestStoreOf<DashboardFeature> {
        await TestStore(initialState: initial) {
            DashboardFeature()
        } withDependencies: {
            $0.date = .constant(Date(timeIntervalSince1970: 0))
            // refreshAfterMutation 的四條 effect
            $0.ledgerClient.listActiveAccounts = { [Self.sampleAccount] }
            $0.ledgerClient.balances           = { [Self.sampleAccount.id: 1000] }
            $0.ledgerClient.listAll            = { _ in [EnrichedTransaction(transaction: Self.sampleTransaction)] }
            $0.insightsClient.todayStats       = { _ in StatsSnapshot(today: 100, week: 400, savingsPercentage: 0.25) }
            $0.insightsClient.weeklySparkline  = { _ in [10, 20, 30, 40, 50, 60, 70] }
            // AddTransactionFeature 子 reducer 需要
            $0.ledgerClient.listCategories     = { _ in [] }
            $0.ledgerClient.defaultAccountId   = { nil }
            $0.captureClient.isAvailable       = { false }
            // TransactionDetailFeature 子 reducer 需要
            $0.ledgerClient.listAccounts       = { [] }
            $0.insightsClient.detailStats      = { _ in TransactionInsight(kind: .fallback(monthlyCategoryCount: 0)) }
            // generateInsights 不在 refreshAfterMutation 路徑中，但 in-flight 保險
            $0.insightsClient.generateInsights = { _ in [] }
        }
    }

    // MARK: - 入口 1：addTransaction.delegate(.saved)

    @Test("addTransaction.delegate.saved → refreshAfterMutation fires and all section phases become loaded")
    func testAddTransactionSavedFiresRefresh() async {
        var initial = DashboardFeature.State()
        // 直接在 initial state 設 addTransaction（不觸發子 feature .task）
        initial.addTransaction = AddTransactionFeature.State(mode: .add(.expense))

        let store = await makeStore(initial: initial)
        await MainActor.run { store.exhaustivity = .off }

        // 送 presented delegate(.saved)
        await store.send(.addTransaction(.presented(.delegate(.saved))))

        // skipReceivedActions 等待所有 effects（refreshAfterMutation 的四條 + 子 feature 的 optionsLoaded 等）完成
        await store.skipReceivedActions()
        await store.finish()

        // 斷言四個 section 的 phase 均為 loaded，確認 refreshAfterMutation 全部執行
        await MainActor.run {
            #expect(store.state.accounts == [Self.sampleAccount])
            #expect(store.state.accountsPhase == .loaded)
            #expect(store.state.recentTransactions == [Self.sampleTransaction])
            #expect(store.state.transactionsPhase == .loaded)
            #expect(store.state.todaySpending == 100)
            #expect(store.state.statsPhase == .loaded)
            #expect(store.state.weeklySpending == [10, 20, 30, 40, 50, 60, 70])
            #expect(store.state.heroPhase == .loaded)
        }
    }

    // MARK: - 入口 2：addTransaction.delegate(.savedRecurringConfirmation)

    @Test("addTransaction.delegate.savedRecurringConfirmation → refreshAfterMutation + delegate forwarded to parent")
    func testAddTransactionSavedRecurringConfirmationFiresRefreshAndForwardsDelegate() async {
        let recurringId = UUID()
        let newNextDue  = Date(timeIntervalSince1970: 2_000_000)

        var initial = DashboardFeature.State()
        initial.addTransaction = AddTransactionFeature.State(mode: .add(.expense))

        let store = await makeStore(initial: initial)
        await MainActor.run { store.exhaustivity = .off }

        await store.send(
            .addTransaction(.presented(.delegate(.savedRecurringConfirmation(recurringId, newNextDue))))
        )

        // delegate 往上轉送（DashboardFeature 用 .send(.delegate(...)) 發出）
        await store.receive(\.delegate.savedRecurringConfirmation) { _ in }

        // 等待 refresh effects 完成
        await store.skipReceivedActions()
        await store.finish()

        await MainActor.run {
            #expect(store.state.accounts == [Self.sampleAccount])
            #expect(store.state.accountsPhase == .loaded)
            #expect(store.state.recentTransactions == [Self.sampleTransaction])
            #expect(store.state.transactionsPhase == .loaded)
            #expect(store.state.todaySpending == 100)
            #expect(store.state.statsPhase == .loaded)
            #expect(store.state.weeklySpending == [10, 20, 30, 40, 50, 60, 70])
            #expect(store.state.heroPhase == .loaded)
        }
    }

    // MARK: - 入口 3a：detail.delegate(.deleted)

    @Test("detail.delegate.deleted → refreshAfterMutation fires and all section phases become loaded")
    func testDetailDelegateDeletedFiresRefresh() async {
        var initial = DashboardFeature.State()
        initial.recentTransactions = [Self.sampleTransaction]
        initial.detail = TransactionDetailFeature.State(transaction: Self.sampleTransaction)

        let store = await makeStore(initial: initial)
        await MainActor.run { store.exhaustivity = .off }

        await store.send(
            .detail(.presented(.delegate(.deleted(Self.sampleTransaction.id))))
        )

        await store.skipReceivedActions()
        await store.finish()

        await MainActor.run {
            #expect(store.state.accounts == [Self.sampleAccount])
            #expect(store.state.accountsPhase == .loaded)
            #expect(store.state.recentTransactions == [Self.sampleTransaction])
            #expect(store.state.transactionsPhase == .loaded)
            #expect(store.state.todaySpending == 100)
            #expect(store.state.statsPhase == .loaded)
            #expect(store.state.heroPhase == .loaded)
        }
    }

    // MARK: - 入口 3b：detail.delegate(.updated)

    @Test("detail.delegate.updated → refreshAfterMutation fires and all section phases become loaded")
    func testDetailDelegateUpdatedFiresRefresh() async {
        let updatedTransaction = Transaction(
            id: Self.sampleTransaction.id,
            amount: 999, date: Self.sampleTransaction.date,
            note: "已修改", categoryId: nil,
            accountId: Self.sampleTransaction.accountId,
            toAccountId: nil, type: .expense
        )

        var initial = DashboardFeature.State()
        initial.recentTransactions = [Self.sampleTransaction]
        initial.detail = TransactionDetailFeature.State(transaction: Self.sampleTransaction)

        let store = await makeStore(initial: initial)
        await MainActor.run { store.exhaustivity = .off }

        await store.send(
            .detail(.presented(.delegate(.updated(updatedTransaction))))
        )

        await store.skipReceivedActions()
        await store.finish()

        await MainActor.run {
            #expect(store.state.accounts == [Self.sampleAccount])
            #expect(store.state.accountsPhase == .loaded)
            #expect(store.state.recentTransactions == [Self.sampleTransaction])
            #expect(store.state.transactionsPhase == .loaded)
            #expect(store.state.todaySpending == 100)
            #expect(store.state.statsPhase == .loaded)
            #expect(store.state.heroPhase == .loaded)
        }
    }
}
