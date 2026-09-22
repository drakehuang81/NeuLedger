import Foundation
import Dependencies
import Domain

/// Live implementation of `PlanningClient`.
///
/// Budget persistence (CRUD + `listActive`) goes directly through
/// `BudgetStore` (no repository indirection).
/// `currentStatus` and `evaluateAfterTransaction` read in-period
/// transactions through `TransactionStore` —
/// filtered inline by date range / category / type, mirroring what the
/// former `BudgetUseCase+Live` obtained via `transactionClient.fetch(_:)`.
/// Warning decision via `Budget.evaluate` (pure entity rule) +
/// `\.notificationAdapter` for delivery.
/// The four budget-warning preferences round-trip through
/// `\.userSettingsAdapter` under the existing `.budgetWarningEnabled` /
/// `.budgetWarningThreshold` keys.
extension PlanningClient: DependencyKey {
    public static var liveValue: PlanningClient {
        let budgetStore = BudgetStore()
        let transactionStore = TransactionStore()
        @Dependency(\.notificationAdapter) var notificationAdapter
        @Dependency(\.userSettingsAdapter) var userSettingsAdapter

        return PlanningClient(
            listAll: {
                try await budgetStore.fetchAll()
            },
            listActive: {
                try await budgetStore.fetchAll().filter { $0.isActive }
            },
            create: { budget in
                try await budgetStore.add(budget)
            },
            update: { budget in
                try await budgetStore.update(budget)
            },
            delete: { id in
                try await budgetStore.delete(id: id)
            },
            currentStatus: { budget in
                let range = budget.period.closedRange(containing: Date())
                let all = try await transactionStore.fetchAll()
                let inPeriod = all.filter { txn in
                    guard range.contains(txn.date) else { return false }
                    guard txn.type == .expense else { return false }
                    guard let scopedCategoryId = budget.categoryId else { return true }
                    return txn.categoryId == scopedCategoryId
                }
                let spent = inPeriod.reduce(Decimal.zero) { $0 + $1.amount }
                return BudgetStatus(
                    budget: budget,
                    periodStart: range.lowerBound,
                    periodEnd: range.upperBound,
                    spent: spent
                )
            },
            evaluateAfterTransaction: { _ in
                // The transaction parameter is currently unused — evaluation
                // re-fetches all in-period transactions (same as the former
                // BudgetUseCase+Live.evaluateAfterTransaction did). The brute
                // re-scan keeps behaviour identical to the original.

                guard userSettingsAdapter.bool(.budgetWarningEnabled) else { return }
                let threshold = userSettingsAdapter.int(.budgetWarningThreshold)
                guard let activeBudgets = try? await budgetStore.fetchAll().filter({ $0.isActive })
                else { return }

                let today = Date()
                let all = (try? await transactionStore.fetchAll()) ?? []

                for budget in activeBudgets {
                    let range = budget.period.closedRange(containing: today)
                    let inPeriod = all.filter { range.contains($0.date) }

                    let formatter = ISO8601DateFormatter()
                    formatter.formatOptions = [.withFullDate]
                    let pKey = formatter.string(from: range.lowerBound)
                    let bidStr = budget.id.uuidString
                    let lastWarned = notificationAdapter.lastWarnedPercent(bidStr, pKey)

                    let outcome = budget.evaluate(
                        transactionsInPeriod: inPeriod,
                        threshold: threshold,
                        lastWarnedPercent: lastWarned
                    )
                    guard outcome.shouldWarn else { continue }

                    let title = String(localized: "notification_budget_warning_title", bundle: .main)
                    let body = String(
                        format: String(localized: "notification_budget_warning_body", bundle: .main),
                        budget.name,
                        outcome.usedPercent
                    )
                    try? await notificationAdapter.sendBudgetWarning(bidStr, title, body)
                    notificationAdapter.setLastWarnedPercent(outcome.usedPercent, bidStr, pKey)
                }
            },
            warningEnabled: {
                userSettingsAdapter.bool(.budgetWarningEnabled)
            },
            setWarningEnabled: { enabled in
                userSettingsAdapter.setBool(enabled, .budgetWarningEnabled)
            },
            warningThreshold: {
                userSettingsAdapter.int(.budgetWarningThreshold)
            },
            setWarningThreshold: { percent in
                userSettingsAdapter.setInt(percent, .budgetWarningThreshold)
            }
        )
    }
}
