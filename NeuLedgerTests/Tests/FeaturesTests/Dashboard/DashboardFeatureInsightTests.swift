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
        await store.skipReceivedActions()
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
        await store.skipReceivedActions()
        await store.finish()

        let summary = try #require(capture.captured)
        #expect(summary.weekTotal == 3_000, "weekTotal 必須來自 todayStats，不是 0")
        #expect(summary.monthTotal == 20_000, "monthTotal 必須是 categoryProportions 的總和，不是 0")
        #expect(summary.topCategoryName == "交通", "top category 必須來自真實資料的第一筆")
        #expect(summary.topCategoryAmount == 11_600)
        // 原值轉手，不重算 —— InsightComposer 用 `!= 0` 精確比較，任何算術都會留殘渣。
        #expect(summary.savingsPercentage == 0.28)
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
        await store.skipReceivedActions()
        await store.finish()

        let card = try #require(await MainActor.run { store.state.insights.first })
        // 不比對整句文案（那會把測試綁死在文字上），只釘住「真實數字有出現」。
        #expect(card.metric == "42%")
        #expect(card.body.contains(Decimal(8_400).twdFormatted),
                "卡片內文必須帶格式化後的真實金額")
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
