import Foundation
import Dependencies
import DependenciesMacros

/// A client interface for the Insights context — every read-only
/// computed view over the ledger, plus the on-device AI narrative
/// features that are "summaries of existing data".
///
/// `InsightsClient` consolidates what previously lived across
/// `AnalyticsUseCase` (the six statistical projections + the
/// `generateAIInsight` entry point) and the read-side AI features of
/// `AIUseCase` (`generateInsight`, `generateInsights`,
/// `answerFinancialQuestion`, and the model-availability check). The
/// Features layer drives all insight / analysis concerns through this
/// single client.
///
/// All entry points are pure derived reads — none mutates the ledger.
@DependencyClient
public struct InsightsClient: Sendable {
    /// Today's expense total + last-7-days expense total + 7-day
    /// savings ratio, all anchored to `referenceDate`. Use the
    /// reference date so previews / tests can pin a clock without
    /// depending on `Date()`.
    public var todayStats: @Sendable (_ referenceDate: Date) async throws -> StatsSnapshot = { _ in .zero }

    /// Per-day expense sums for the most recent 7 days (index 6 is the
    /// reference day), optionally scoped to a single account.
    public var weeklySparkline: @Sendable (_ accountId: Account.ID?) async throws -> [Decimal] = { _ in Array(repeating: 0, count: 7) }

    /// Per-day expense bars over an arbitrary interval. Returned in
    /// ascending date order; days with no expenses are omitted.
    public var dailyBars: @Sendable (_ range: DateInterval) async throws -> [DailyTrend] = { _ in [] }

    /// Category-by-category expense shares over an arbitrary interval.
    /// Returned sorted by amount descending.
    public var categoryProportions: @Sendable (_ range: DateInterval) async throws -> [CategoryProportion] = { _ in [] }

    /// Gauge-ready metrics for every currently-active budget.
    /// Optionally scoped to budgets relevant to the given account
    /// (only those whose `categoryId` appears in the account's recent
    /// expenses).
    public var budgetGauges: @Sendable (_ accountId: Account.ID?) async throws -> [BudgetGaugeMetrics] = { _ in [] }

    /// Compute insight context for a single transaction — same-category
    /// monthly average for expenses, prior same-category amount for
    /// income, monthly transfer activity for transfers.
    public var detailStats: @Sendable (_ transaction: Transaction) async throws -> TransactionInsight

    /// Natural-language insight string for the given `SpendingSummary`.
    /// Cache-backed within a session — same summary returns the cached
    /// inference. Lives here because it's a summary read, not a write.
    public var generateAIInsight: @Sendable (_ summary: SpendingSummary) async throws -> String

    /// Carousel-style list of insights for the Dashboard B1 redesign.
    public var generateInsights: @Sendable (_ summary: SpendingSummary) async throws -> [InsightData] = { _ in [] }

    /// 「用自然語言讀帳本」——自 AIUseCase 搬入（含 QueryTransactionsTool）。
    /// Tool-calling QA over the user's transaction history.
    public var answerFinancialQuestion: @Sendable (_ question: String) async throws -> String

    /// 洞察類 AI 功能可用性（AIAssistant/Analysis/Dashboard 的顯示判斷）。
    /// Whether the on-device language model is available.
    public var isAIAvailable: @Sendable () -> Bool = { false }
}

extension InsightsClient: TestDependencyKey {
    public static let testValue = Self()
}

public extension DependencyValues {
    var insightsClient: InsightsClient {
        get { self[InsightsClient.self] }
        set { self[InsightsClient.self] = newValue }
    }
}
