import Foundation
import SwiftData
import Domain
import Dependencies

/// Live implementation of `TransactionClient` backed by SwiftData.
extension TransactionClient: DependencyKey {
    public static var liveValue: TransactionClient {
        @Dependency(\.databaseClient) var databaseClient
        @Dependency(\.budgetClient) var budgetClient
        @Dependency(\.notificationClient) var notificationClient
        @Dependency(\.userSettingsClient) var userSettingsClient

        return TransactionClient(
            fetchRecent: {
                var descriptor = FetchDescriptor<SDTransaction>(
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                )
                descriptor.fetchLimit = 20
                return try databaseClient.fetch(descriptor)
            },
            fetchAll: {
                try databaseClient.fetch(
                    FetchDescriptor<SDTransaction>(
                        sortBy: [SortDescriptor(\.date, order: .reverse)]
                    )
                )
            },
            fetch: { filter in
                let context = databaseClient.makeContext()

                // Build base descriptor and fetch all, then filter in-memory
                // for complex multi-criteria filtering that SwiftData predicates
                // don't easily compose.
                let descriptor = FetchDescriptor<SDTransaction>(
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                )
                var results = try context.fetch(descriptor)

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
                    let rawTypes = types.map(\.rawValue)
                    results = results.filter { rawTypes.contains($0.type) }
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

                return results.map { $0.toDomain() }
            },
            search: { query in
                let context = databaseClient.makeContext()
                let lowered = query.lowercased()
                let descriptor = FetchDescriptor<SDTransaction>(
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                )
                let all = try context.fetch(descriptor)
                let filtered = all.filter {
                    $0.note?.lowercased().contains(lowered) ?? false
                }
                return filtered.map { $0.toDomain() }
            },
            add: { transaction in
                try databaseClient.add(transaction, as: SDTransaction.self)
                await checkBudgetWarnings(
                    budgetClient: budgetClient,
                    notificationClient: notificationClient,
                    userSettingsClient: userSettingsClient,
                    databaseClient: databaseClient
                )
            },
            update: { transaction in
                let txnId = transaction.id
                try databaseClient.update(
                    matching: FetchDescriptor<SDTransaction>(
                        predicate: #Predicate { $0.id == txnId }
                    )
                ) { existing, context in
                    existing.amount = transaction.amount
                    existing.date = transaction.date
                    existing.note = transaction.note
                    existing.categoryId = transaction.categoryId
                    existing.accountId = transaction.accountId
                    existing.toAccountId = transaction.toAccountId
                    existing.type = transaction.type.rawValue
                    existing.aiSuggested = transaction.aiSuggested
                    existing.updatedAt = transaction.updatedAt
                    existing.tags = transaction.tags.map { SDTag.resolve($0, context: context) }
                }
                await checkBudgetWarnings(
                    budgetClient: budgetClient,
                    notificationClient: notificationClient,
                    userSettingsClient: userSettingsClient,
                    databaseClient: databaseClient
                )
            },
            delete: { id in
                try databaseClient.deleteFirst(
                    matching: FetchDescriptor<SDTransaction>(
                        predicate: #Predicate { $0.id == id }
                    )
                )
            },
            weeklySpending: { accountID, days in
                try databaseClient.weeklySpendingSums(accountID: accountID, days: days)
            },
            statsSnapshot: {
                try databaseClient.statsSnapshot()
            },
            detailStats: { transaction in
                let context = databaseClient.makeContext()
                let cal = Calendar.current
                guard let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: transaction.date)) else {
                    return TransactionInsight(kind: .fallback(monthlyCategoryCount: 0))
                }
                guard let monthEnd = cal.date(byAdding: .month, value: 1, to: monthStart) else {
                    return TransactionInsight(kind: .fallback(monthlyCategoryCount: 0))
                }
                let descriptor = FetchDescriptor<SDTransaction>(
                    predicate: #Predicate { $0.date >= monthStart && $0.date < monthEnd }
                )
                let rows = try context.fetch(descriptor)
                let categoryId = transaction.categoryId
                let expenseRaw = TransactionType.expense.rawValue
                let incomeRaw = TransactionType.income.rawValue
                let transferRaw = TransactionType.transfer.rawValue

                switch transaction.type {
                case .transfer:
                    let monthCount = rows.filter { $0.type == transferRaw }.count
                    let monthTotal = rows.filter { $0.type == transferRaw }.reduce(Decimal(0)) { $0 + $1.amount }
                    return TransactionInsight(kind: .transfer(monthCount: monthCount, monthTotal: monthTotal))

                case .income:
                    let sameCategory = rows.filter { $0.type == incomeRaw && $0.categoryId == categoryId }
                    let monthlyCount = sameCategory.count
                    let netMonth = sameCategory.reduce(Decimal(0)) { $0 + $1.amount }
                    // Find the most recent prior same-category income before this month — fetch in-memory
                    let priorDescriptor = FetchDescriptor<SDTransaction>(
                        predicate: #Predicate { $0.date < monthStart },
                        sortBy: [SortDescriptor(\.date, order: .reverse)]
                    )
                    let priorRows = try context.fetch(priorDescriptor)
                    let prior = priorRows.first { $0.type == incomeRaw && $0.categoryId == categoryId }
                    let lastAmount = prior.map { $0.amount } ?? Decimal(0)
                    let percentDelta: Double
                    if lastAmount > 0 {
                        let diff = NSDecimalNumber(decimal: transaction.amount - lastAmount).doubleValue
                        let base = NSDecimalNumber(decimal: lastAmount).doubleValue
                        percentDelta = diff / base
                    } else {
                        percentDelta = 0
                    }
                    return TransactionInsight(kind: .incomeVsLast(
                        percentDelta: percentDelta,
                        lastAmount: lastAmount,
                        monthlyCount: monthlyCount,
                        netMonth: netMonth
                    ))

                case .expense:
                    let sameCategory = rows.filter { $0.type == expenseRaw && $0.categoryId == categoryId }
                    let monthlyCount = sameCategory.count
                    let monthTotal = sameCategory.reduce(Decimal(0)) { $0 + $1.amount }
                    let avg: Decimal = monthlyCount > 0 ? monthTotal / Decimal(monthlyCount) : Decimal(0)
                    let percentDelta: Double
                    if avg > 0 {
                        let diff = NSDecimalNumber(decimal: transaction.amount - avg).doubleValue
                        let base = NSDecimalNumber(decimal: avg).doubleValue
                        percentDelta = diff / base
                    } else {
                        percentDelta = 0
                    }
                    return TransactionInsight(kind: .expenseVsCategoryAvg(
                        percentDelta: percentDelta,
                        avg: avg,
                        monthlyCount: monthlyCount,
                        monthTotal: monthTotal
                    ))
                }
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
private func checkBudgetWarnings(
    budgetClient: BudgetClient,
    notificationClient: NotificationClient,
    userSettingsClient: UserSettingsClient,
    databaseClient: DatabaseClient
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

        // categoryId is UUID? — build Set<UUID>? accordingly
        let categoryIds: Set<UUID>? = budget.categoryId.map { Set([$0]) }
        let filter = TransactionFilter(
            categoryIds: categoryIds,
            types: Set([.expense]),
            // DateInterval.end is exclusive — subtract 1ms so ClosedRange excludes the next period's start.
            dateRange: interval.start...interval.end.addingTimeInterval(-0.001)
        )

        // Fetch transactions directly through databaseClient to avoid recursive dependency
        let transactions: [Transaction]
        do {
            let context = databaseClient.makeContext()
            let descriptor = FetchDescriptor<SDTransaction>(
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            var results = try context.fetch(descriptor)
            if let catIds = filter.categoryIds {
                results = results.filter { txn in
                    guard let catId = txn.categoryId else { return false }
                    return catIds.contains(catId)
                }
            }
            if let types = filter.types {
                let rawTypes = types.map(\.rawValue)
                results = results.filter { rawTypes.contains($0.type) }
            }
            if let dateRange = filter.dateRange {
                results = results.filter { dateRange.contains($0.date) }
            }
            transactions = results.map { $0.toDomain() }
        } catch {
            continue
        }

        let totalSpent = transactions.reduce(into: Decimal(0)) { $0 += $1.amount }
        let ratio = (totalSpent / budget.amount * 100) as NSDecimalNumber
        let usedPercent = ratio.intValue   // truncation is intentional (conservative)

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        let pKey = formatter.string(from: interval.start)

        // budget.id is UUID — use .uuidString as the String key
        let bidStr = budget.id.uuidString
        let lastWarned = notificationClient.lastWarnedPercent(bidStr, pKey)
        guard usedPercent >= threshold,
              lastWarned == nil || lastWarned! < threshold else { continue }

        let title = String(localized: "notification_budget_warning_title", bundle: .main)
        let body = String(
            format: String(localized: "notification_budget_warning_body", bundle: .main),
            budget.name,
            usedPercent
        )
        try? await notificationClient.sendBudgetWarning(bidStr, title, body)
        notificationClient.setLastWarnedPercent(usedPercent, bidStr, pKey)
    }
}
