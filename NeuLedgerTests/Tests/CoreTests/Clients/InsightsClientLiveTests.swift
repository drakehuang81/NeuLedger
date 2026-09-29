import Testing
import SwiftData
import Foundation
import Dependencies
import Domain
@testable import Core

/// Live tests for `InsightsClient`.
///
/// The six statistical projections are migrated equivalents of the
/// former `TransactionClient` stats tests (`statsSnapshot` /
/// `weeklySpending` / `detailStats`) and the `AnalyticsUseCase`
/// `budgetGauges` path — all now exercised through
/// `InsightsClient.liveValue`. The AI cases cover model availability
/// (via a stubbed `AIAdapter`) and the `generateAIInsight` cache
/// behaviour (same `SpendingSummary` must hit the cache and avoid a
/// second adapter call).
@Suite("InsightsClient Live Tests")
struct InsightsClientLiveTests {

    /// Fresh in-memory container holding the full schema.
    private func freshContainer() throws -> ModelContainer {
        let schema = Schema([
            SDTransaction.self,
            SDAccount.self,
            SDCategory.self,
            SDBudget.self,
            SDTag.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    /// Builds the live client wired to a given container and an optional
    /// `AIAdapter` override.
    private func sut(_ container: ModelContainer, aiAdapter: AIAdapter? = nil) -> InsightsClient {
        withDependencies {
            $0.persistenceBootstrap = PersistenceBootstrap(modelContainer: { container })
            $0.modelContainer = container
            if let aiAdapter { $0.aiAdapter = aiAdapter }
        } operation: {
            InsightsClient.liveValue
        }
    }

    private func insert(_ tx: SDTransaction, into container: ModelContainer) throws {
        let ctx = ModelContext(container)
        ctx.insert(tx)
        try ctx.save()
    }

    private func expenseTx(amount: Decimal, date: Date, accountId: String, categoryId: UUID? = nil) -> SDTransaction {
        SDTransaction(
            id: UUID(), amount: amount, date: date, note: "",
            categoryId: categoryId, accountId: accountId, toAccountId: nil,
            type: TransactionType.expense.rawValue,
            aiSuggested: false, createdAt: date, updatedAt: date
        )
    }

    // MARK: - todayStats (migrated from TransactionClientStatsTests)

    @Test("todayStats computes today + week + savings %")
    func testTodayStats() async throws {
        let container = try freshContainer()
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let acct = UUID().uuidString
        try insert(expenseTx(amount: 200, date: today, accountId: acct), into: container)
        let d3 = cal.date(byAdding: .day, value: -3, to: today)!
        try insert(expenseTx(amount: 100, date: d3, accountId: acct), into: container)
        let ctx = ModelContext(container)
        ctx.insert(SDTransaction(
            id: UUID(), amount: 1000, date: d3, note: "",
            categoryId: nil, accountId: acct, toAccountId: nil,
            type: TransactionType.income.rawValue,
            aiSuggested: false, createdAt: d3, updatedAt: d3
        ))
        try ctx.save()

        let client = sut(container)
        let snap = try await client.todayStats(Date())
        #expect(snap.today == 200)
        #expect(snap.week == 300)
        let rate = try #require(snap.savingsPercentage, "有收入紀錄時儲蓄率必須算得出來")
        #expect(abs(rate - 0.7) < 0.001)
    }

    @Test("todayStats 在支出大於收入時回報負儲蓄率，不夾成 0")
    func testTodayStatsReportsNegativeSavings() async throws {
        let container = try freshContainer()
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let acct = UUID().uuidString
        let d3 = cal.date(byAdding: .day, value: -3, to: today)!
        try insert(expenseTx(amount: 1_500, date: d3, accountId: acct), into: container)
        let ctx = ModelContext(container)
        ctx.insert(SDTransaction(
            id: UUID(), amount: 1_000, date: d3, note: "",
            categoryId: nil, accountId: acct, toAccountId: nil,
            type: TransactionType.income.rawValue,
            aiSuggested: false, createdAt: d3, updatedAt: d3
        ))
        try ctx.save()

        let snap = try await sut(container).todayStats(Date())

        // 舊實作是 `max(0, saved / inc)`，這裡會拿到 0；而 0 在 InsightComposer
        // 眼中等同「沒資料」，於是入不敷出的人連卡片都看不到。
        let rate = try #require(snap.savingsPercentage)
        #expect(abs(rate - (-0.5)) < 0.001, "(1000 - 1500) / 1000 = -0.5")
    }

    @Test("todayStats 在期間內沒有任何收入時回報 nil，不是 0")
    func testTodayStatsReportsNilSavingsWithoutIncome() async throws {
        let container = try freshContainer()
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let acct = UUID().uuidString
        try insert(expenseTx(amount: 200, date: today, accountId: acct), into: container)

        let snap = try await sut(container).todayStats(Date())

        #expect(snap.today == 200, "前提：這筆支出確實落在統計窗內")
        #expect(snap.savingsPercentage == nil,
                "分母是 0，儲蓄率沒有定義——回 0 會被畫面讀成「一毛都沒存下來」")
    }

    // MARK: - weeklySparkline (migrated from TransactionClientWeeklyTests)

    @Test("weeklySparkline returns 7 entries summed per day, oldest to newest")
    func testWeeklySparkline() async throws {
        let container = try freshContainer()
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let acct = UUID().uuidString
        for i in 0 ..< 7 {
            let date = cal.date(byAdding: .day, value: -i, to: today)!
            try insert(expenseTx(amount: Decimal(100 * (i + 1)), date: date, accountId: acct), into: container)
        }

        let client = sut(container)
        let result = try await client.weeklySparkline(nil)
        #expect(result.count == 7)
        #expect(result[6] == 100)   // today
        #expect(result[0] == 700)   // 6 days ago
    }

    // MARK: - detailStats (migrated from TransactionClientDetailStatsTests)

    @Test("detailStats returns expenseVsCategoryAvg")
    func testDetailStats() async throws {
        let container = try freshContainer()
        let now = Date()
        let acct = "11000000-0000-0000-0000-000000000001"
        let catFood = UUID(uuidString: "33000000-0000-0000-0000-000000000001")!
        let subject = Transaction(amount: 250, date: now, categoryId: catFood, accountId: acct, type: .expense)
        let other = Transaction(amount: 150, date: now, categoryId: catFood, accountId: acct, type: .expense)
        let ctx = ModelContext(container)
        SDTransaction.from(subject, context: ctx)
        SDTransaction.from(other, context: ctx)
        try ctx.save()

        let client = sut(container)
        let insight = try await client.detailStats(subject)
        guard case let .expenseVsCategoryAvg(_, avg, count, total) = insight.kind else {
            Issue.record("Expected expenseVsCategoryAvg, got \(insight.kind)")
            return
        }
        #expect(count == 2)
        #expect(total == 400)
        #expect(avg == 200)
    }

    // MARK: - budgetGauges (active budgets read directly via SwiftDataStore)

    @Test("budgetGauges reads active budgets directly and computes spent")
    func testBudgetGauges() async throws {
        let container = try freshContainer()
        let ctx = ModelContext(container)

        let budgetId = UUID()
        let activeBudget = Budget(
            id: budgetId, name: "食費", amount: 1000, categoryId: nil,
            period: .monthly, startDate: Date(), isActive: true
        )
        let inactiveBudget = Budget(
            id: UUID(), name: "停用", amount: 5000, categoryId: nil,
            period: .monthly, startDate: Date(), isActive: false
        )
        SDBudget.from(activeBudget, context: ctx)
        SDBudget.from(inactiveBudget, context: ctx)
        try ctx.save()

        // Two in-period expenses summing to 300.
        let now = Date()
        let acct = UUID().uuidString
        try insert(expenseTx(amount: 200, date: now, accountId: acct), into: container)
        try insert(expenseTx(amount: 100, date: now, accountId: acct), into: container)

        let client = sut(container)
        let gauges = try await client.budgetGauges(nil)
        #expect(gauges.count == 1) // only the active budget
        #expect(gauges.first?.id == budgetId.uuidString)
        #expect(gauges.first?.spentAmount == 300)
        #expect(gauges.first?.totalBudget == 1000)
    }

    @Test("budgetGauges for a category-scoped budget counts only that category (scalarTransaction maps categoryId)")
    func testBudgetGaugesCategoryScoped() async throws {
        let container = try freshContainer()
        let ctx = ModelContext(container)
        let food = UUID()
        let transport = UUID()
        let budget = Budget(
            id: UUID(), name: "餐費", amount: 1000, categoryId: food,
            period: .monthly, startDate: Date(), isActive: true
        )
        SDBudget.from(budget, context: ctx)
        try ctx.save()

        let now = Date()
        let acct = UUID().uuidString
        try insert(expenseTx(amount: 300, date: now, accountId: acct, categoryId: food), into: container)
        try insert(expenseTx(amount: 250, date: now, accountId: acct, categoryId: transport), into: container)
        try insert(expenseTx(amount: 30, date: now, accountId: acct, categoryId: nil), into: container)

        let gauges = try await sut(container).budgetGauges(nil)
        #expect(gauges.count == 1)
        #expect(gauges.first?.id == budget.id.uuidString)
        #expect(gauges.first?.spentAmount == 300)
    }

    // MARK: - Analysis projections (financialSummary / dailyBars / categoryProportions)

    private func incomeTx(amount: Decimal, date: Date, accountId: String) -> SDTransaction {
        SDTransaction(
            id: UUID(), amount: amount, date: date, note: "",
            categoryId: nil, accountId: accountId, toAccountId: nil,
            type: TransactionType.income.rawValue,
            aiSuggested: false, createdAt: date, updatedAt: date
        )
    }

    @Test("financialSummary sums income/expense in range, excludes transfers, scopes to account")
    func testFinancialSummary() async throws {
        let container = try freshContainer()
        let now = Date()
        let range = BudgetPeriod.monthly.dateInterval(containing: now)
        let a = UUID().uuidString
        let b = UUID().uuidString
        try insert(expenseTx(amount: 300, date: now, accountId: a), into: container)
        try insert(expenseTx(amount: 120, date: now, accountId: b), into: container)
        try insert(incomeTx(amount: 5000, date: now, accountId: a), into: container)
        let transfer = SDTransaction(
            id: UUID(), amount: 999, date: now, note: "",
            categoryId: nil, accountId: a, toAccountId: b,
            type: TransactionType.transfer.rawValue,
            aiSuggested: false, createdAt: now, updatedAt: now
        )
        try insert(transfer, into: container)
        try insert(expenseTx(amount: 777, date: range.start.addingTimeInterval(-60), accountId: a), into: container)

        let client = sut(container)
        let all = try await client.financialSummary(range, nil)
        #expect(all == FinancialSummary(totalIncome: 5000, totalExpense: 420))
        let onlyA = try await client.financialSummary(range, a)
        #expect(onlyA == FinancialSummary(totalIncome: 5000, totalExpense: 300))
    }

    @Test("dailyBars scoped to account only counts that account's expenses")
    func testDailyBarsAccountScope() async throws {
        let container = try freshContainer()
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let range = BudgetPeriod.monthly.dateInterval(containing: today)
        let a = UUID().uuidString
        let b = UUID().uuidString
        try insert(expenseTx(amount: 100, date: today.addingTimeInterval(3600), accountId: a), into: container)
        try insert(expenseTx(amount: 50, date: today.addingTimeInterval(7200), accountId: b), into: container)

        let client = sut(container)
        let all = try await client.dailyBars(range, nil)
        #expect(all == [DailyTrend(date: today, amount: 150)])
        let onlyA = try await client.dailyBars(range, a)
        #expect(onlyA == [DailyTrend(date: today, amount: 100)])
    }

    @Test("categoryProportions resolves seed names via localizedName and buckets uncategorized under the stable id")
    func testCategoryProportionsNamesAndUncategorized() async throws {
        let container = try freshContainer()
        let ctx = ModelContext(container)
        let food = Category(name: "Food", icon: "fork.knife", color: "#FF6B6B", type: .expense, isDefault: true)
        SDCategory.from(food, context: ctx)
        try ctx.save()

        let now = Date()
        let range = BudgetPeriod.monthly.dateInterval(containing: now)
        let acct = UUID().uuidString
        try insert(expenseTx(amount: 300, date: now, accountId: acct, categoryId: food.id), into: container)
        try insert(expenseTx(amount: 120, date: now, accountId: acct, categoryId: nil), into: container)

        let result = try await sut(container).categoryProportions(range, nil)
        #expect(result.count == 2)
        #expect(result[0].id == food.id.uuidString)
        // 這條斷言在預設的 en 模擬器上無鑑別力——seed 分類「Food」的 en 在地化值
        // 就是 "Food"，跟未 localise 的 `name` 相同，兩種實作都會過。真正有鑑別力
        // 的是下面 `result[1].name` 那條：舊 kernel 硬編 "—"，en/zh-Hant 都不是
        // "—"。已用 `-testLanguage zh-Hant -testRegion TW` 額外驗證過這條在有
        // 鑑別力的語系下是真的通過（`food.localizedName` → "餐飲"）。
        #expect(result[0].name == food.localizedName)   // zh-Hant → "餐飲"，en → "Food"
        #expect(result[0].amount == 300)
        #expect(result[0].isUnassigned == false, "真實分類不可被誤標成未分類")
        #expect(result[1].id == CategoryProportion.uncategorizedId)
        #expect(result[1].name == String(localized: "analysis_other_category", bundle: .main))
        #expect(result[1].amount == 120)
        // C3：Dashboard 的「本月最大支出分類」靠這個旗標跳過未分類桶
        // （`filter { !$0.isUnassigned }`）。拿掉生產碼的 `isUnassigned: true`
        // 不會讓任何其他測試變紅（init 預設值就是 `false`），所以這裡必須釘住。
        #expect(result[1].isUnassigned == true)
    }

    @Test("categoryProportions scoped to an account excludes other accounts' expenses")
    func testCategoryProportionsAccountScope() async throws {
        let container = try freshContainer()
        let ctx = ModelContext(container)
        let food = Category(name: "Food", icon: "fork.knife", color: "#FF6B6B", type: .expense, isDefault: true)
        SDCategory.from(food, context: ctx)
        try ctx.save()

        let now = Date()
        let range = BudgetPeriod.monthly.dateInterval(containing: now)
        let a = UUID().uuidString
        let b = UUID().uuidString
        try insert(expenseTx(amount: 300, date: now, accountId: a, categoryId: food.id), into: container)
        try insert(expenseTx(amount: 120, date: now, accountId: b, categoryId: food.id), into: container)

        let onlyA = try await sut(container).categoryProportions(range, a)
        #expect(onlyA.count == 1)
        #expect(onlyA[0].amount == 300)   // 不是 420（沒篩）也不是 120（篩反）
    }

    // MARK: - isAIAvailable (reflects AIAdapter)

    @Test("isAIAvailable reflects AIAdapter availability — true")
    func testIsAIAvailableTrue() async throws {
        let container = try freshContainer()
        var adapter = AIAdapter.testValue
        adapter.isAvailable = { true }
        let client = sut(container, aiAdapter: adapter)
        #expect(client.isAIAvailable() == true)
    }

    @Test("isAIAvailable reflects AIAdapter availability — false")
    func testIsAIAvailableFalse() async throws {
        let container = try freshContainer()
        var adapter = AIAdapter.testValue
        adapter.isAvailable = { false }
        let client = sut(container, aiAdapter: adapter)
        #expect(client.isAIAvailable() == false)
    }

    // MARK: - generateAIInsight cache behaviour

    @Test("generateAIInsight caches by summary — second call hits cache, no second adapter call")
    func testGenerateAIInsightCaches() async throws {
        let container = try freshContainer()

        // Unique periodDescription so the process-shared InsightCache
        // (static let) cannot be polluted by other tests.
        let summary = SpendingSummary(
            totalIncome: 5000,
            totalExpense: 2000,
            categoryBreakdown: [:],
            periodDescription: "cache-test-\(UUID().uuidString)"
        )

        let callCount = CallCounter()
        var adapter = AIAdapter.testValue
        adapter.generateText = { _ in
            await callCount.increment()
            return "洞察：本期支出 NT$2,000"
        }

        let client = sut(container, aiAdapter: adapter)
        let first = try await client.generateAIInsight(summary)
        let second = try await client.generateAIInsight(summary)

        #expect(first == "洞察：本期支出 NT$2,000")
        #expect(second == first)
        let count = await callCount.value
        #expect(count == 1, "adapter.generateText should only be called once thanks to the cache")
    }

    private actor CallCounter {
        private(set) var value = 0
        func increment() { value += 1 }
    }
}
