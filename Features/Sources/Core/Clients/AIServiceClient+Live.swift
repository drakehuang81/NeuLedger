import Foundation
import FoundationModels
import Domain
import Dependencies

// MARK: - QueryTransactionsTool

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

        // Resolve category name to ID (case-insensitive match)
        var categoryIds: [Domain.Category.ID]? = nil
        if let name = arguments.category {
            let matched = allCategories.filter {
                $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame
            }
            if !matched.isEmpty {
                categoryIds = matched.map(\.id)
            }
        }

        // Parse date range
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
            return "查無交易紀錄。"
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let lines = transactions.map { t in
            "\(formatter.string(from: t.date)) \(t.note ?? "（無備註）") NT$\(t.amount)"
        }
        return lines.joined(separator: "\n")
    }
}

extension AIServiceClient: DependencyKey {
    // InsightCache is a static let so it is created once for the app session and shared
    // by all generateInsight calls — not reset each time liveValue is accessed.
    private static let insightCache = InsightCache()

    public static let liveValue = AIServiceClient(

        // MARK: - extractTransaction
        // A fresh LanguageModelSession per call — no shared context needed for single-shot extraction.
        // Throws on failure so the caller (Feature layer) decides: show error or silently ignore.
        extractTransaction: { input in
            let session = LanguageModelSession()
            let prompt = """
            從以下輸入解析出一筆交易紀錄，金額單位為新台幣（TWD）。
            所有文字欄位請使用繁體中文。
            輸入：\(input)
            """
            // respond(to:generating:) returns LanguageModelSession.Response<ExtractedTransaction>.
            // Access .content to unwrap the actual ExtractedTransaction value.
            return try await session.respond(to: prompt, generating: ExtractedTransaction.self).content
        },

        // MARK: - suggestCategories
        // Passing the full existing category list constrains the model to known names,
        // preventing hallucinated categories that don't exist in the user's data.
        suggestCategories: { description, existingCategories in
            let session = LanguageModelSession()
            let categoryList = existingCategories.joined(separator: "、")
            let prompt = """
            根據以下交易描述，從分類清單中選出最合適的分類（最多3個，依相關性排序）。
            請只從清單中選擇，不要建議清單以外的分類。
            交易描述：\(description)
            可用分類：\(categoryList)
            """
            return try await session.respond(to: prompt, generating: CategorySuggestions.self).content
        },

        // MARK: - generateInsight
        // Same SpendingSummary within a session hits the cache — no repeated inference for
        // the Analysis screen's period switcher (week/month/year all stay cached after first load).
        generateInsight: { summary in
            if let cached = await AIServiceClient.insightCache.get(for: summary) { return cached }
            let session = LanguageModelSession()
            let prompt = """
            請用繁體中文撰寫一段簡短的消費分析洞察（2-3句話）。
            時間範圍：\(summary.periodDescription)
            總收入：NT$\(summary.totalIncome)
            總支出：NT$\(summary.totalExpense)
            各分類支出：\(summary.categoryBreakdown.map { "\($0.key): NT$\($0.value)" }.joined(separator: "、"))
            """
            let result = try await session.respond(to: prompt).content
            await AIServiceClient.insightCache.set(result, for: summary)
            return result
        },

        // MARK: - answerFinancialQuestion
        // Uses Foundation Models Tool Calling: the model decides when to invoke QueryTransactionsTool
        // to fetch real transaction data, then synthesises a natural language answer in Traditional Chinese.
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

        // MARK: - isAvailable
        // Synchronous — safe to call on any thread without await.
        // Returns false if the device doesn't support Foundation Models or the model isn't downloaded.
        isAvailable: {
            SystemLanguageModel.default.isAvailable
        }
    )
}
