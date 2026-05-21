import Foundation
import FoundationModels
import Domain
import Dependencies

// MARK: - QueryTransactionsTool

/// Foundation Models `Tool` exposed during `answerFinancialQuestion`
/// so the model can fetch real transaction rows instead of
/// hallucinating amounts. Implementation crosses two Repositories
/// (transactions + categories), so it stays inside `AIUseCase+Live`
/// rather than `AIAdapter+Live` — the Adapter layer doesn't know
/// about other Repositories per architecture.md §10.
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

    let transactionClient: TransactionClient
    let categoryClient: CategoryClient

    func call(arguments: Arguments) async throws -> String {
        let allCategories = try await categoryClient.fetchAll()

        var categoryIds: [Domain.Category.ID]? = nil
        if let name = arguments.category {
            let matched = allCategories.filter {
                $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame
            }
            if !matched.isEmpty {
                categoryIds = matched.map(\.id)
            }
        }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withFullDate]
        let start = arguments.startDate.flatMap { iso.date(from: $0) }
        let end = arguments.endDate.flatMap { iso.date(from: $0) }
        let dateRange: ClosedRange<Date>? = (start != nil || end != nil)
            ? (start ?? .distantPast)...(end ?? .distantFuture)
            : nil

        let filter = TransactionFilter(
            categoryIds: categoryIds.map(Set.init),
            dateRange: dateRange
        )
        let transactions = try await transactionClient.fetch(filter)

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

extension AIUseCase: DependencyKey {
    // InsightCache is a static let so it is created once for the app
    // session and shared by all generateInsight calls — not reset each
    // time liveValue is accessed.
    private static let insightCache = InsightCache()

    private static func listSeparator() -> String {
        Locale.current.language.languageCode?.identifier.hasPrefix("zh") == true ? "、" : ", "
    }

    public static var liveValue: AIUseCase {
        @Dependency(\.aiAdapter) var aiAdapter

        // MARK: - extract* implementations
        // extractFromText / extractFromVoice / extractTransaction share
        // identical implementation today. Keeping them as separate
        // closures lets future voice-specific prompt tuning land in
        // extractFromVoice alone.
        let extract: @Sendable (String) async throws -> ExtractedTransaction = { input in
            let template = String(localized: "ai_prompt_extract_transaction", bundle: .main)
            let prompt = String(format: template, input)
            return try await aiAdapter.extractTransaction(prompt)
        }

        return AIUseCase(
            extractFromText: extract,
            extractFromVoice: extract,
            extractTransaction: extract,

            suggestCategories: { description, existingCategories in
                let categoryList = existingCategories.joined(separator: listSeparator())
                let template = String(localized: "ai_prompt_suggest_categories", bundle: .main)
                let prompt = String(format: template, description, categoryList)
                return try await aiAdapter.suggestCategories(prompt)
            },

            // Same SpendingSummary within a session hits the cache —
            // no repeated inference for the Analysis screen's period
            // switcher (week/month/year all stay cached after first
            // load).
            generateInsight: { summary in
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

            // Tool-calling stays in the UseCase (not the Adapter)
            // because the tool implementation crosses multiple
            // Repositories — that's UseCase territory.
            answerFinancialQuestion: { question in
                @Dependency(\.transactionClient) var transactionClient
                @Dependency(\.categoryClient) var categoryClient
                let tool = QueryTransactionsTool(
                    transactionClient: transactionClient,
                    categoryClient: categoryClient
                )
                let session = LanguageModelSession(tools: [tool])
                return try await session.respond(to: question).content
            },

            isAvailable: {
                aiAdapter.isAvailable()
            }
        )
    }
}
