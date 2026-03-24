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
            }
        )
    }
}

// MARK: - Budget Warning Helper

/// Checks all active budgets and fires a notification if any crosses the user-defined threshold.
/// Called after add/update only — NOT after delete (intentional simplification).
/// String(localized:bundle:.main) in Core is acceptable; AIServiceClient+Live.swift uses the same pattern.
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
        let interval: DateInterval
        switch budget.period {
        case .weekly:  interval = cal.dateInterval(of: .weekOfYear, for: today)!
        case .monthly: interval = cal.dateInterval(of: .month, for: today)!
        case .yearly:  interval = cal.dateInterval(of: .year, for: today)!
        }

        // categoryId is UUID? — build Set<UUID>? accordingly
        let categoryIds: Set<UUID>? = budget.categoryId.map { Set([$0]) }
        let filter = TransactionFilter(
            categoryIds: categoryIds,
            types: Set([.expense]),
            dateRange: interval.start...interval.end
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
        await notificationClient.sendBudgetWarning(bidStr, title, body)
        notificationClient.setLastWarnedPercent(usedPercent, bidStr, pKey)
    }
}
