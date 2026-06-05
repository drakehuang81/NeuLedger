import Foundation
import FoundationModels
import SwiftData
import Dependencies
import Domain

// MARK: - QueryTransactionsTool

/// Foundation Models `Tool` exposed during `answerFinancialQuestion`
/// so the model can fetch real transaction rows instead of
/// hallucinating amounts.
///
/// Migrated from `AIUseCase+Live`. The former implementation injected
/// `transactionClient` + `categoryClient`; as an Insights read-only
/// projection this version reads `SwiftDataStore` directly and filters
/// inline (Insights does not depend on other Clients).
private struct QueryTransactionsTool: Tool {
    let description = "Query the user's transaction history by category name and/or date range"

    @Generable
    struct Arguments {
        @Guide(description: "Category name to filter by. Omit to include all categories.")
        var category: String?
        @Guide(description: "Start date in ISO 8601 format (YYYY-MM-DD). Omit for no lower bound.")
        var startDate: String?
        @Guide(description: "End date in ISO 8601 format (YYYY-MM-DD). Omit for no upper bound.")
        var endDate: String?
    }

    let transactionStore: TransactionStore
    let categoryStore: CategoryStore

    func call(arguments: Arguments) async throws -> String {
        let allCategories = try await categoryStore.fetchAll()

        var categoryIds: Set<Domain.Category.ID>? = nil
        if let name = arguments.category {
            let matched = allCategories.filter {
                $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame
            }
            if !matched.isEmpty {
                categoryIds = Set(matched.map(\.id))
            }
        }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withFullDate]
        let start = arguments.startDate.flatMap { iso.date(from: $0) }
        let end = arguments.endDate.flatMap { iso.date(from: $0) }
        let dateRange: ClosedRange<Date>? = (start != nil || end != nil)
            ? (start ?? .distantPast)...(end ?? .distantFuture)
            : nil

        // Inline filter mirroring the former `transactionClient.fetch(filter)`.
        let all = try await transactionStore.fetchAll()
        let transactions = all.filter { txn in
            if let categoryIds {
                guard let cid = txn.categoryId, categoryIds.contains(cid) else { return false }
            }
            if let dateRange {
                guard dateRange.contains(txn.date) else { return false }
            }
            return true
        }

        if transactions.isEmpty {
            return String(localized: "ai_tool_no_transactions", bundle: .main)
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let noNote = String(localized: "ai_tool_no_note", bundle: .main)
        let lines = transactions.map { t in
            "\(formatter.string(from: t.date)) \(t.note ?? noNote) NT$\(t.amount)"
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - Live

/// Live implementation of `InsightsClient`.
///
/// The six statistical projections delegate to
/// `TransactionAnalyticsKernel` (migrated unchanged from
/// `AnalyticsUseCase+Live`; container reached via `\.persistenceBootstrap`).
/// `budgetGauges` reads active budgets through
/// `BudgetStore` directly (Insights is a read-only
/// projection and must not depend on `PlanningClient`); category names
/// for `categoryProportions` / `budgetGauges` come from
/// `CategoryStore`.
///
/// The AI features are migrated from `AIUseCase+Live`:
/// `generateAIInsight` is the de-duplicated single entry point
/// (the former `AnalyticsUseCase.generateAIInsight` merely forwarded to
/// `AIUseCase.generateInsight`, so the cache-backed `AIUseCase`
/// implementation is authoritative). `answerFinancialQuestion` carries
/// `QueryTransactionsTool`, and `isAIAvailable` reflects `AIAdapter`.
extension InsightsClient: DependencyKey {
    // InsightCache is a static let so it is created once for the app
    // session and shared by all generateAIInsight calls — not reset
    // each time liveValue is accessed (preserved from AIUseCase+Live).
    private static let insightCache = InsightCache()

    private static func listSeparator() -> String {
        Locale.current.language.languageCode?.identifier.hasPrefix("zh") == true ? "、" : ", "
    }

    public static var liveValue: InsightsClient {
        // Container is reached via `PersistenceBootstrap` rather than
        // `\.modelContainer` directly — architecture.md §4.2 reserves
        // `@Dependency(\.modelContainer)` for `SwiftDataStore` only.
        @Dependency(\.persistenceBootstrap) var persistenceBootstrap
        @Dependency(\.aiAdapter) var aiAdapter

        let budgetStore = BudgetStore()
        let categoryStore = CategoryStore()
        let transactionStore = TransactionStore()

        return InsightsClient(
            todayStats: { referenceDate in
                try TransactionAnalyticsKernel.statsSnapshot(
                    referenceDate: referenceDate,
                    container: persistenceBootstrap.modelContainer()
                )
            },
            weeklySparkline: { accountID in
                try TransactionAnalyticsKernel.weeklySpending(
                    accountID: accountID,
                    days: 7,
                    container: persistenceBootstrap.modelContainer()
                )
            },
            dailyBars: { range in
                try TransactionAnalyticsKernel.dailyBars(
                    range: range,
                    container: persistenceBootstrap.modelContainer()
                )
            },
            categoryProportions: { range in
                let categories = try await categoryStore.fetchAll()
                let names = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0.name) })
                return try TransactionAnalyticsKernel.categoryProportions(
                    range: range,
                    container: persistenceBootstrap.modelContainer(),
                    categoryNamesById: names
                )
            },
            budgetGauges: { accountId in
                do {
                    let active = try await budgetStore.fetchAll().filter { $0.isActive }
                    let categories = try await categoryStore.fetchAll()
                    let names = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0.name) })
                    return try TransactionAnalyticsKernel.budgetGauges(
                        accountId: accountId,
                        activeBudgets: active,
                        categoryNamesById: names,
                        container: persistenceBootstrap.modelContainer()
                    )
                } catch {
                    return []
                }
            },
            detailStats: { transaction in
                try TransactionAnalyticsKernel.detailStats(
                    for: transaction,
                    container: persistenceBootstrap.modelContainer()
                )
            },

            // De-duplicated entry point. The former
            // `AnalyticsUseCase.generateAIInsight` forwarded to
            // `AIUseCase.generateInsight`; this is that cache-backed
            // implementation verbatim. Same SpendingSummary within a
            // session hits the cache — no repeated inference for the
            // Analysis screen's period switcher.
            generateAIInsight: { summary in
                if let cached = await insightCache.get(for: summary) { return cached }
                let template = String(localized: "ai_prompt_generate_insight", bundle: .main)
                var prompt = String(format: template,
                    summary.periodDescription,
                    "\(summary.totalIncome)",
                    "\(summary.totalExpense)")
                if !summary.categoryBreakdown.isEmpty {
                    let categoryText = summary.categoryBreakdown
                        .map { "\($0.key): NT$\($0.value)" }
                        .joined(separator: listSeparator())
                    let categoryLine = String(
                        format: String(localized: "ai_prompt_category_breakdown", bundle: .main),
                        categoryText)
                    prompt += "\n" + categoryLine
                }
                let result = try await aiAdapter.generateText(prompt)
                await insightCache.set(result, for: summary)
                return result
            },

            // TODO: replace with FoundationModels output — currently
            // returns 3 hard-coded entries matching the designer-
            // supplied B1 Warm Redesign copy. Schema is stable so
            // swapping in a real LLM call requires no reducer change.
            generateInsights: { _ in
                [
                    InsightData(
                        title: "本週支出減少 12%",
                        body: "你比上週省下 NT$ 3,200，可以考慮加碼儲蓄",
                        metric: "-12%",
                        metricColor: .income,
                        cta: "查看分析"
                    ),
                    InsightData(
                        title: "餐飲花費偏高",
                        body: "本月已花 NT$ 8,400，佔總支出 42%",
                        metric: "42%",
                        metricColor: .expense,
                        cta: "設定預算"
                    ),
                    InsightData(
                        title: "儲蓄率達標",
                        body: "本月儲蓄率 28%，超出目標 5%",
                        metric: "28%",
                        metricColor: .accent,
                        cta: "查看詳情"
                    )
                ]
            },

            // Tool-calling QA. Tool reads SwiftData directly (Insights
            // owns no other Client). Migrated from AIUseCase+Live.
            answerFinancialQuestion: { question in
                let tool = QueryTransactionsTool(
                    transactionStore: transactionStore,
                    categoryStore: categoryStore
                )
                let session = LanguageModelSession(tools: [tool])
                return try await session.respond(to: question).content
            },

            isAIAvailable: {
                aiAdapter.isAvailable()
            }
        )
    }
}
