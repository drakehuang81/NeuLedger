import Foundation
import Dependencies
import DependenciesMacros

/// Application-layer use case for all read-only computed views over
/// the ledger.
///
/// Surface follows `docs/architecture.md` §5 Insights Context. Owns
/// everything that's a "summary of existing data" — including AI
/// insight generation, since that's a derived read rather than a
/// write side effect. Use sites that currently call
/// `TransactionClient.weeklySpending / statsSnapshot / detailStats`
/// migrate here in Phase 6.
@DependencyClient
public struct AnalyticsUseCase: Sendable {
    /// Today's expense total + last-7-days expense total + 7-day
    /// savings ratio, all anchored to `referenceDate`. Use the
    /// reference date so previews / tests can pin a clock without
    /// depending on `Date()`.
    public var todayStats: @Sendable (_ referenceDate: Date) async throws -> StatsSnapshot = { _ in .zero }

    /// Per-day expense sums for the most recent 7 days (index 6 is
    /// the reference day), optionally scoped to a single account.
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
    /// Lives here (not in AIUseCase) because it's a summary read rather
    /// than a write action — architecture.md §5.
    public var generateAIInsight: @Sendable (_ summary: SpendingSummary) async throws -> String
}

extension AnalyticsUseCase: TestDependencyKey {
    public static let testValue = Self()
}

public extension DependencyValues {
    var analyticsUseCase: AnalyticsUseCase {
        get { self[AnalyticsUseCase.self] }
        set { self[AnalyticsUseCase.self] = newValue }
    }
}
