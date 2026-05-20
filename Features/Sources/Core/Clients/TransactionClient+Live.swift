import Foundation
import SwiftData
import Domain
import Dependencies

/// Live implementation of `TransactionClient` backed by `SwiftDataStore`.
///
/// The `weeklySpending`, `statsSnapshot`, and `detailStats` endpoints
/// still delegate to `DatabaseClient` helpers — those are analytics
/// concerns that move to `AnalyticsUseCase` in Phase 5. Until then this
/// file is the only Repository Live that retains a `databaseClient`
/// dependency, and only for those three analytic endpoints.
extension TransactionClient: DependencyKey {
    public static var liveValue: TransactionClient {
        @Dependency(\.databaseClient) var databaseClient
        @Dependency(\.budgetClient) var budgetClient
        @Dependency(\.notificationAdapter) var notificationAdapter
        @Dependency(\.userSettingsClient) var userSettingsClient

        let store = SwiftDataStore<Transaction, SDTransaction>()

        return TransactionClient(
            fetchRecent: {
                let all = try await store.fetchAll(
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                )
                return Array(all.prefix(20))
            },
            fetchAll: {
                try await store.fetchAll(sortBy: [SortDescriptor(\.date, order: .reverse)])
            },
            fetch: { filter in
                var results = try await store.fetchAll(
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                )

                if let categoryIds = filter.categoryIds {
                    results = results.filter { txn in
                        guard let catId = txn.categoryId else { return false }
                        return categoryIds.contains(catId)
                    }
                }
                if let accountIds = filter.accountIds {
                    results = results.filter { accountIds.contains($0.accountId) }
                }
                if let tagIds = filter.tagIds {
                    results = results.filter { txn in
                        txn.tags.contains { tagIds.contains($0.id) }
                    }
                }
                if let types = filter.types {
                    results = results.filter { types.contains($0.type) }
                }
                if let dateRange = filter.dateRange {
                    results = results.filter { dateRange.contains($0.date) }
                }
                if let searchText = filter.searchText, !searchText.isEmpty {
                    let lowered = searchText.lowercased()
                    results = results.filter {
                        $0.note?.lowercased().contains(lowered) ?? false
                    }
                }
                return results
            },
            search: { query in
                let lowered = query.lowercased()
                let all = try await store.fetchAll(
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                )
                return all.filter { $0.note?.lowercased().contains(lowered) ?? false }
            },
            add: { transaction in
                try await store.add(transaction)
                await checkBudgetWarnings(
                    budgetClient: budgetClient,
                    notificationAdapter: notificationAdapter,
                    userSettingsClient: userSettingsClient,
                    transactionStore: store
                )
            },
            update: { transaction in
                try await store.update(transaction)
                await checkBudgetWarnings(
                    budgetClient: budgetClient,
                    notificationAdapter: notificationAdapter,
                    userSettingsClient: userSettingsClient,
                    transactionStore: store
                )
            },
            delete: { id in
                try await store.delete(id: id)
            },
            weeklySpending: { accountID, days in
                try databaseClient.weeklySpendingSums(accountID: accountID, days: days)
            },
            statsSnapshot: {
                try databaseClient.statsSnapshot()
            },
            detailStats: { transaction in
                try databaseClient.detailStats(for: transaction)
            }
        )
    }
}

// MARK: - Budget Warning Helper

/// Checks all active budgets and fires a notification if any crosses the user-defined threshold.
/// Called after add/update only — NOT after delete (intentional simplification).
/// NOTE: localization keys are resolved from the app's main bundle because the
/// `Localizable.xcstrings` catalog lives in the app target, not in the Core SPM package.
/// Switching to `Bundle.module` would require moving or duplicating the catalog into Core.
///
/// This helper is the last Repository-layer site that mixes business logic
/// with persistence. Phase 4 of the architecture migration extracts it into
/// `LedgerUseCase.record` + `BudgetUseCase.evaluateAfterTransaction` per
/// docs/architecture.md §3.1 Scenario B (post-condition invariant).
private func checkBudgetWarnings(
    budgetClient: BudgetClient,
    notificationAdapter: NotificationAdapter,
    userSettingsClient: UserSettingsClient,
    transactionStore: SwiftDataStore<Transaction, SDTransaction>
) async {
    guard userSettingsClient.bool(.budgetWarningEnabled) else { return }
    let threshold = userSettingsClient.int(.budgetWarningThreshold)
    guard let activeBudgets = try? await budgetClient.fetchActive() else { return }

    let today = Date()
    for budget in activeBudgets {
        guard budget.amount > 0 else { continue }

        let cal = Calendar.current
        let component: Calendar.Component
        switch budget.period {
        case .weekly:  component = .weekOfYear
        case .monthly: component = .month
        case .yearly:  component = .year
        }
        guard let interval = cal.dateInterval(of: component, for: today) else { continue }

        // Fetch all transactions and filter in Swift — matches the pattern
        // used everywhere else in this Live implementation.
        let allTransactions: [Transaction]
        do {
            allTransactions = try await transactionStore.fetchAll()
        } catch {
            continue
        }
        // DateInterval.end is exclusive — subtract 1ms so ClosedRange excludes the next period's start.
        let periodRange = interval.start...interval.end.addingTimeInterval(-0.001)
        let inPeriodExpense = allTransactions.filter { txn in
            txn.type == .expense
                && periodRange.contains(txn.date)
                && (budget.categoryId == nil ? true : txn.categoryId == budget.categoryId)
        }

        let totalSpent = inPeriodExpense.reduce(into: Decimal(0)) { $0 += $1.amount }
        let ratio = (totalSpent / budget.amount * 100) as NSDecimalNumber
        let usedPercent = ratio.intValue   // truncation is intentional (conservative)

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        let pKey = formatter.string(from: interval.start)

        let bidStr = budget.id.uuidString
        let lastWarned = notificationAdapter.lastWarnedPercent(bidStr, pKey)
        guard usedPercent >= threshold,
              lastWarned == nil || lastWarned! < threshold else { continue }

        let title = String(localized: "notification_budget_warning_title", bundle: .main)
        let body = String(
            format: String(localized: "notification_budget_warning_body", bundle: .main),
            budget.name,
            usedPercent
        )
        try? await notificationAdapter.sendBudgetWarning(bidStr, title, body)
        notificationAdapter.setLastWarnedPercent(usedPercent, bidStr, pKey)
    }
}
