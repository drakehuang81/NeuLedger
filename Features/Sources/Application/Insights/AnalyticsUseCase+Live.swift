import Foundation
import SwiftData
import Dependencies
import Domain

extension AnalyticsUseCase: DependencyKey {
    public static var liveValue: AnalyticsUseCase {
        // Container is reached via `DatabaseClient` rather than
        // `\.modelContainer` directly — architecture.md §4.2 reserves
        // `@Dependency(\.modelContainer)` for `SwiftDataStore` only.
        @Dependency(\.databaseClient) var databaseClient
        @Dependency(\.planningClient) var planningClient
        @Dependency(\.categoryClient) var categoryClient
        @Dependency(\.aiUseCase) var aiUseCase

        return AnalyticsUseCase(
            todayStats: { referenceDate in
                try TransactionAnalyticsKernel.statsSnapshot(
                    referenceDate: referenceDate,
                    container: databaseClient.modelContainer()
                )
            },
            weeklySparkline: { accountID in
                try TransactionAnalyticsKernel.weeklySpending(
                    accountID: accountID,
                    days: 7,
                    container: databaseClient.modelContainer()
                )
            },
            dailyBars: { range in
                try TransactionAnalyticsKernel.dailyBars(
                    range: range,
                    container: databaseClient.modelContainer()
                )
            },
            categoryProportions: { range in
                let categories = try await categoryClient.fetchAll()
                let names = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0.name) })
                return try TransactionAnalyticsKernel.categoryProportions(
                    range: range,
                    container: databaseClient.modelContainer(),
                    categoryNamesById: names
                )
            },
            budgetGauges: { accountId in
                do {
                    let active = try await planningClient.listActive()
                    let categories = try await categoryClient.fetchAll()
                    let names = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0.name) })
                    return try TransactionAnalyticsKernel.budgetGauges(
                        accountId: accountId,
                        activeBudgets: active,
                        categoryNamesById: names,
                        container: databaseClient.modelContainer()
                    )
                } catch {
                    return []
                }
            },
            detailStats: { transaction in
                try TransactionAnalyticsKernel.detailStats(
                    for: transaction,
                    container: databaseClient.modelContainer()
                )
            },
            generateAIInsight: { summary in
                // UseCase→UseCase composition allowed per architecture.md
                // §5 (Insights Context owns the semantic boundary "this is
                // a derived read"; the FoundationModels call lives in
                // AIUseCase). Not a §3.1 invariant — caller is free to
                // skip AI insight without breaking the analytics flow.
                try await aiUseCase.generateInsight(summary)
            }
        )
    }
}
