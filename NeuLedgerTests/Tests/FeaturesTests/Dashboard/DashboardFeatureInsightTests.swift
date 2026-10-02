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
        // 這條測的是「幾張卡 + index 歸零 + phase」。期望值是 `mock.map(insightCard(for:))`，
        // 也就是**被測函式算了等號兩邊**——它對映射本身恆成立，刻意如此：三種 Kind 的映射
        // 各自由「寫死期望值」的測試釘住（topCategory →
        // testDescriptorIsLocalisedWithTheFormattedAmount、savingsRate →
        // testPercentIsRounded、weekSpending → testWeekSpendingCardIsCompactAndNeutral）。
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
        // 同 testLoad：這裡測的是 retry 真的重跑了 effect，映射本身由三條字面期望值的
        // 測試釘住（見 testLoad 的註解）。
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
            // top category 的**選法**（跳過未分類、不依賴排序）由
            // testTopCategorySkipsUnassignedAndIgnoresOrdering 釘住；這條只管
            // 「summary 帶的是真實數字而不是 0」。
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
        #expect(summary.topCategoryName == "交通", "top category 必須來自真實資料")
        #expect(summary.topCategoryAmount == 11_600)
        // 原值轉手，不重算 —— InsightComposer 用 `!= 0` 精確比較，任何算術都會留殘渣。
        #expect(summary.savingsPercentage == 0.28)
    }

    /// F2 + F3：「—」那桶是 kernel 給「沒有分類的支出」的合計，不是使用者的分類——
    /// 它金額最大時，首屏會出現「「—」花了 NT$20,000，佔本月支出的 50%」。
    /// 而選法也不能依賴「`categoryProportions` 保證降冪」這個零測試的契約，所以 stub
    /// 刻意**不按金額排序**。`monthTotal` 反過來**要**含未分類那桶：文案是「佔本月
    /// 支出的」，分母就是總支出。
    @Test("the top category is the biggest categorised bucket, whatever the order, and never the unassigned one")
    func testTopCategorySkipsUnassignedAndIgnoresOrdering() async throws {
        let capture = SummaryCapture()
        let store = await TestStore(initialState: DashboardFeature.State()) {
            DashboardFeature()
        } withDependencies: {
            $0.date = .constant(Date(timeIntervalSince1970: 1_700_000_000))
            $0.insightsClient.todayStats = { _ in .zero }
            // 金額最大的是未分類桶，且三筆刻意亂序（`first` 會拿到 8,400 的餐飲）。
            $0.insightsClient.categoryProportions = { _ in
                [
                    CategoryProportion(name: "餐飲", amount: 8_400),
                    CategoryProportion(name: "—", amount: 20_000, isUnassigned: true),
                    CategoryProportion(name: "交通", amount: 11_600)
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
        // 只斷言 spy 捕到的 summary，不碰 state → `finish()` 就夠。
        await store.finish()

        let summary = try #require(capture.captured)
        #expect(
            summary.topCategoryName == "交通",
            "必須是金額最大的**已分類**項目：不是未分類的「—」，也不是陣列第一筆"
        )
        #expect(summary.topCategoryAmount == 11_600)
        #expect(
            summary.monthTotal == 40_000,
            "monthTotal 是總支出，含未分類那桶（8,400 + 20,000 + 11,600）"
        )
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

    /// F1：`.weekSpending` 的映射以前**完全沒被釘住**——testLoad / testRetry 都用
    /// `mock.map(insightCard(for:))` 當期望值（被測函式算了等號兩邊），所以把生產碼的
    /// `metric` 從 `twdCompact` 改成 `twdFormatted`、或 `metricColor` 從 `.neutral` 改成
    /// `.expense`，全 suite 仍然綠。這條把三個欄位都寫成**字面**期望值。
    ///
    /// 金額刻意取 12,000（≥ 10,000）：`twdCompact` 對 < 10,000 的值會直接退回
    /// `twdFormatted`，用小額做這條測試抓不到 compact / formatted 被對調。
    @Test("a weekSpending descriptor becomes a card with a compact metric and a neutral colour")
    func testWeekSpendingCardIsCompactAndNeutral() {
        let descriptor = InsightDescriptor(kind: .weekSpending(12_000))
        let card = DashboardFeature.insightCard(for: descriptor)

        // MetricBadge 空間有限 → badge 用 compact。字面寫出 "NT$1.2萬"：`twdCompact` 的
        // `%.1f` 走 POSIX 小數點、單位是寫死的中文字，不隨 locale 變。
        #expect(card.metric == "NT$1.2萬", "badge 必須是 compact 格式，不是完整金額")
        #expect(card.metricColor == .neutral, "近 7 天支出是中性資訊，不染支出色")
        // 內文相反：完整金額。期望值用同一個 bundle 模板、但參數寫死，所以文案可以改、
        // 也不綁 locale，而「內文帶 twdFormatted 而不是 compact」一改就紅。
        let expectedBody = String(
            format: String(localized: "dashboard_insight_week_body", bundle: .main),
            Decimal(12_000).twdFormatted
        )
        #expect(card.body == expectedBody)
        #expect(card.body.contains(Decimal(12_000).twdFormatted))
        #expect(card.title == String(localized: "dashboard_insight_week_title", bundle: .main))
        #expect(card.id == descriptor.id, "id 沿用描述子，不在映射時另生一組 UUID")
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

    @Test("負儲蓄率換成入不敷出的文案，不是把負號塞進同一句")
    func testNegativeSavingsUsesTheOverspendCopy() {
        let positive = DashboardFeature.insightCard(for: InsightDescriptor(kind: .savingsRate(0.15)))
        let negative = DashboardFeature.insightCard(for: InsightDescriptor(kind: .savingsRate(-0.15)))

        #expect(negative.title != positive.title, "標題必須換掉——「儲蓄率」配一個負數讀不通")
        #expect(negative.body != positive.body)
        #expect(negative.body.contains("-") == false,
                "內文講的是「多花了 15%」，負號不該出現在句子裡")
        #expect(negative.body.contains("15%"), "內文要帶絕對值")
        #expect(negative.metric == "-15%", "badge 仍然顯示帶負號的原始數字")
        #expect(negative.metricColor == .expense)
    }
}
