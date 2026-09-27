import Testing
import ComposableArchitecture
import Foundation
import Common
@testable import Features
import Domain

@Suite("DashboardFeature Insight Carousel")
struct DashboardFeatureInsightTests {

    /// 捕捉 `generateInsights` 實際收到的 summary。`@unchecked Sendable` + NSLock
    /// 是這個 codebase 既有 spy 的寫法。
    private final class SummaryCapture: @unchecked Sendable {
        private let lock = NSLock()
        private var value: SpendingSummary?
        func record(_ s: SpendingSummary) { lock.lock(); value = s; lock.unlock() }
        var captured: SpendingSummary? { lock.lock(); defer { lock.unlock() }; return value }
    }

    /// 捕捉 `categoryProportions` 實際收到的查詢區間。
    private final class RangeCapture: @unchecked Sendable {
        private let lock = NSLock()
        private var value: DateInterval?
        func record(_ r: DateInterval) { lock.lock(); value = r; lock.unlock() }
        var captured: DateInterval? { lock.lock(); defer { lock.unlock() }; return value }
    }

    /// 數 `generateInsights` 被呼叫幾次（用來釘住 mutation 後有重載）。
    private final class CallCounter: @unchecked Sendable {
        private let lock = NSLock()
        private var count = 0
        func bump() { lock.lock(); count += 1; lock.unlock() }
        var value: Int { lock.lock(); defer { lock.unlock() }; return count }
    }

    @Test("Loads 3 insights and sets insightIndex to 0")
    func testLoad() async {
        let mock = [
            InsightDescriptor(kind: .topCategory(name: "餐飲", amount: 8_400, share: 0.42)),
            InsightDescriptor(kind: .savingsRate(0.28)),
            InsightDescriptor(kind: .weekSpending(3_000))
        ]
        let store = await TestStore(initialState: DashboardFeature.State()) {
            DashboardFeature()
        } withDependencies: {
            $0.date = .constant(Date(timeIntervalSince1970: 0))
            $0.insightsClient.generateInsights = { _ in mock }
            $0.insightsClient.weeklySparkline = { _ in [] }
            $0.insightsClient.todayStats = { _ in .zero }
            $0.insightsClient.categoryProportions = { _ in [] }
            $0.ledgerClient.listAll = { _ in [] }
            $0.ledgerClient.balances = { [:] }
            $0.ledgerClient.listActiveAccounts = { [] }
            $0.ledgerClient.listCategories = { _ in [] }
        }
        await MainActor.run {
            store.exhaustivity = .off
        }
        await store.send(.task)
        // 這條測的是「幾張卡 + index 歸零 + phase」；映射本身由
        // testDescriptorIsLocalisedWithTheFormattedAmount 釘住。
        await store.receive(\.insightsLoaded) {
            $0.insights = mock.map(DashboardFeature.insightCard(for:))
            $0.insightIndex = 0
            $0.insightPhase = .loaded
        }
        // 刻意不用 `skipReceivedActions()`：它在 action 佇列已被前面的 `receive`
        // 耗盡時會誤判成失敗。`finish()` 本身就會等所有 effect 收尾。
        await store.finish()
    }

    @Test("insightIndexChanged updates the index, clamped to valid range")
    func testIndex() async {
        var initial = DashboardFeature.State()
        initial.insights = [
            InsightData(title: "A", body: "a", metric: "1%", metricColor: .income),
            InsightData(title: "B", body: "b", metric: "2%", metricColor: .income),
            InsightData(title: "C", body: "c", metric: "3%", metricColor: .income)
        ]
        let store = await TestStore(initialState: initial) {
            DashboardFeature()
        }
        await store.send(.insightIndexChanged(2)) {
            $0.insightIndex = 2
        }
        await store.send(.insightIndexChanged(-5)) {
            $0.insightIndex = 0
        }
        await store.send(.insightIndexChanged(99)) {
            $0.insightIndex = 2
        }
    }

    @Test("retrySection(.insight) re-runs the effect")
    func testRetry() async {
        let mock = [InsightDescriptor(kind: .weekSpending(1_200))]
        var initial = DashboardFeature.State()
        initial.insightPhase = .failed("x")
        let store = await TestStore(initialState: initial) {
            DashboardFeature()
        } withDependencies: {
            // insightsEffect 現在要讀 `now` 才能算出當月區間，
            // 並且會先查 categoryProportions / todayStats 才組 summary。
            $0.date = .constant(Date(timeIntervalSince1970: 1_700_000_000))
            $0.insightsClient.categoryProportions = { _ in [] }
            $0.insightsClient.todayStats = { _ in .zero }
            $0.insightsClient.generateInsights = { _ in mock }
        }
        await store.send(.retrySection(.insight)) {
            $0.insightPhase = .loading
        }
        await store.receive(\.insightsLoaded) {
            $0.insights = mock.map(DashboardFeature.insightCard(for:))
            $0.insightIndex = 0
            $0.insightPhase = .loaded
        }
    }

    /// audit B9 的核心：`insightsEffect` 以前傳
    /// `SpendingSummary(monthTotal: 0, weekTotal: 0)`（全 0）給 `generateInsights`，
    /// 所以 client 端必須寫死假金額才看起來有內容。
    @Test("the summary handed to generateInsights carries real totals, not zeros")
    func testInsightsEffectBuildsARealSummary() async throws {
        let capture = SummaryCapture()
        let store = await TestStore(initialState: DashboardFeature.State()) {
            DashboardFeature()
        } withDependencies: {
            $0.date = .constant(Date(timeIntervalSince1970: 1_700_000_000))
            $0.insightsClient.todayStats = { _ in
                StatsSnapshot(today: 500, week: 3_000, savingsPercentage: 0.28)
            }
            // `categoryProportions` 依約定已按金額降冪，所以 effect 直接取 `first`。
            $0.insightsClient.categoryProportions = { _ in
                [
                    CategoryProportion(name: "交通", amount: 11_600),
                    CategoryProportion(name: "餐飲", amount: 8_400)
                ]
            }
            $0.insightsClient.generateInsights = { summary in
                capture.record(summary)
                return []
            }
            $0.insightsClient.weeklySparkline = { _ in [] }
            $0.ledgerClient.listAll = { _ in [] }
            $0.ledgerClient.balances = { [:] }
            $0.ledgerClient.listActiveAccounts = { [] }
            $0.ledgerClient.listCategories = { _ in [] }
        }
        await MainActor.run { store.exhaustivity = .off }

        await store.send(.task)
        // 刻意不用 `skipReceivedActions()`：它在 action 佇列已被耗盡時會誤判成
        // 失敗（`.task` merge 多條 effect，抵達順序不定）。`finish()` 就夠了。
        await store.finish()

        let summary = try #require(capture.captured)
        #expect(summary.weekTotal == 3_000, "weekTotal 必須來自 todayStats，不是 0")
        #expect(summary.monthTotal == 20_000, "monthTotal 必須是 categoryProportions 的總和，不是 0")
        #expect(summary.topCategoryName == "交通", "top category 必須來自真實資料的第一筆")
        #expect(summary.topCategoryAmount == 11_600)
        // 原值轉手，不重算 —— InsightComposer 用 `!= 0` 精確比較，任何算術都會留殘渣。
        #expect(summary.savingsPercentage == 0.28)
    }

    /// 卡片文案說「佔**本月**支出的」，所以查詢區間必須真的是當月。
    /// 每一處 stub 都寫成 `categoryProportions = { _ in ... }` 把 `DateInterval`
    /// 丟掉，所以少了這條，把生產碼的 `BudgetPeriod.monthly` 改成 `.weekly` 會全綠。
    @Test("categoryProportions is queried for the current month, not some other period")
    func testInsightsQueryTheCurrentMonth() async throws {
        let fixedNow = Date(timeIntervalSince1970: 1_700_000_000)
        let capture = RangeCapture()
        let store = await TestStore(initialState: DashboardFeature.State()) {
            DashboardFeature()
        } withDependencies: {
            $0.date = .constant(fixedNow)
            $0.insightsClient.categoryProportions = { range in
                capture.record(range)
                return []
            }
            $0.insightsClient.todayStats = { _ in .zero }
            $0.insightsClient.generateInsights = { _ in [] }
            $0.insightsClient.weeklySparkline = { _ in [] }
            $0.ledgerClient.listAll = { _ in [] }
            $0.ledgerClient.balances = { [:] }
            $0.ledgerClient.listActiveAccounts = { [] }
            $0.ledgerClient.listCategories = { _ in [] }
        }
        await MainActor.run { store.exhaustivity = .off }

        await store.send(.task)
        await store.finish()

        let range = try #require(capture.captured)
        #expect(
            range == BudgetPeriod.monthly.dateInterval(containing: fixedNow),
            "區間必須是 BudgetPeriod.monthly 對 `date.now` 算出的當月，不是週或其他期間"
        )
    }

    /// F1：洞察在帳本異動後**必須**重載。空狀態叫使用者「記幾筆帳」，
    /// 記了卻不動的話，比它取代掉的假資料更糟。
    @Test("recording a transaction reloads the insights")
    func testMutationReloadsInsights() async throws {
        let calls = CallCounter()
        var initial = DashboardFeature.State()
        // 直接在 initial state 設 addTransaction，不觸發子 feature 的 .task。
        initial.addTransaction = AddTransactionFeature.State(mode: .add(.expense))

        let store = await TestStore(initialState: initial) {
            DashboardFeature()
        } withDependencies: {
            $0.date = .constant(Date(timeIntervalSince1970: 1_700_000_000))
            $0.insightsClient.generateInsights = { _ in
                calls.bump()
                return [InsightDescriptor(kind: .weekSpending(1_500))]
            }
            $0.insightsClient.categoryProportions = { _ in [] }
            $0.insightsClient.todayStats = { _ in .zero }
            $0.insightsClient.weeklySparkline = { _ in [] }
            $0.ledgerClient.listAll = { _ in [] }
            $0.ledgerClient.balances = { [:] }
            $0.ledgerClient.listActiveAccounts = { [] }
            // AddTransactionFeature 子 reducer 需要
            $0.ledgerClient.listCategories = { _ in [] }
            $0.ledgerClient.defaultAccountId = { nil }
            $0.captureClient.isAvailable = { false }
        }
        await MainActor.run { store.exhaustivity = .off }

        await store.send(.addTransaction(.presented(.delegate(.saved))))
        await store.receive(\.insightsLoaded)
        await store.finish()

        #expect(calls.value >= 1, "refreshAfterMutation 必須重跑 insightsEffect")
        await MainActor.run {
            #expect(store.state.insights.count == 1, "重載後卡片要被填回去")
            #expect(store.state.insightPhase == .loaded)
        }
    }

    /// 描述子只帶數字；標題 / 內文 / 金額格式化都在 Features 層完成。
    @Test("a descriptor becomes a card carrying the formatted amount and percentage")
    func testDescriptorIsLocalisedWithTheFormattedAmount() async throws {
        let descriptors = [
            InsightDescriptor(kind: .topCategory(name: "餐飲", amount: 8_400, share: 0.42))
        ]
        let store = await TestStore(initialState: DashboardFeature.State()) {
            DashboardFeature()
        } withDependencies: {
            $0.date = .constant(Date(timeIntervalSince1970: 1_700_000_000))
            $0.insightsClient.generateInsights = { _ in descriptors }
            $0.insightsClient.todayStats = { _ in .zero }
            $0.insightsClient.categoryProportions = { _ in [] }
            $0.insightsClient.weeklySparkline = { _ in [] }
            $0.ledgerClient.listAll = { _ in [] }
            $0.ledgerClient.balances = { [:] }
            $0.ledgerClient.listActiveAccounts = { [] }
            $0.ledgerClient.listCategories = { _ in [] }
        }
        await MainActor.run { store.exhaustivity = .off }

        await store.send(.task)
        // 這條讀的是 **state**，所以必須讓 `.insightsLoaded` 真的被收下 ——
        // `finish()` 只等 effect 收尾，不會把 received action 灌進 state
        // （少了這一步 `store.state.insights` 會是空的）。用明確的 `receive`
        // 而不是 `skipReceivedActions()`：後者在佇列已耗盡時會誤判成失敗，
        // 前者在 exhaustivity = .off 下會跳過中間的 action 直到對上。
        await store.receive(\.insightsLoaded)
        await store.finish()

        let card = try #require(await MainActor.run { store.state.insights.first })
        #expect(card.metric == "42%")

        // 比對**完整代入後**的字串，而不是一堆 `contains` —— `contains` 擋不住
        // 三個 arg 被對調（分類名 / 金額 / 百分比互換後每一條 contains 仍然成立）。
        // 期望值用同一個 bundle 模板、但**參數順序寫死**，所以模板本身可以改文案、
        // 也不綁 locale，而順序一改就紅。
        let expectedBody = String(
            format: String(localized: "dashboard_insight_top_category_body", bundle: .main),
            "餐飲",
            Decimal(8_400).twdFormatted,
            "42%"
        )
        #expect(card.body == expectedBody,
                "內文必須是「分類名 → 格式化金額 → 百分比」這個順序代入的結果")
        // 順帶確認模板真的被解析、參數真的被代入（而不是三者都缺席時的假綠）。
        #expect(card.body.contains(Decimal(8_400).twdFormatted))
        #expect(card.body.contains("餐飲"))
        #expect(card.metricColor == .expense)
        #expect(card.id == descriptors[0].id, "id 沿用描述子，不在映射時另生一組 UUID")
        #expect(card.cta == nil, "CTA 點擊目前是 no-op，不放沒有作用的按鈕")
    }

    /// 百分比走 `%.0f%%`（四捨五入），不是 `Int()`（截斷）：
    /// 0.426 → 43%，`Int(0.426 * 100)` 會給 42。
    /// （刻意避開 0.425 這種剛好落在 .5 的值 —— printf 對可精確表示的 .5
    /// 走 round-half-to-even，那測的是 libc 而不是這裡的慣例。）
    @Test("percentages are rounded, not truncated")
    func testPercentIsRounded() {
        let card = DashboardFeature.insightCard(
            for: InsightDescriptor(kind: .savingsRate(0.426))
        )
        #expect(card.metric == "43%")
        #expect(card.metricColor == .income)
    }
}
