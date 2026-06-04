import Foundation
import Dependencies
import Domain

/// Live implementation of `PlanningClient`.
///
/// Budget persistence (CRUD + `listActive`) goes directly through
/// `SwiftDataStore<Budget, SDBudget>` (no repository indirection).
/// `currentStatus` and `evaluateAfterTransaction` read in-period
/// transactions through `SwiftDataStore<Transaction, SDTransaction>` —
/// filtered inline by date range / category / type, mirroring what the
/// former `BudgetUseCase+Live` obtained via `transactionClient.fetch(_:)`.
/// Warning fired through `BudgetWarningPolicy` + `\.notificationAdapter`.
/// The four budget-warning preferences round-trip through
/// `\.userSettingsAdapter` under the existing `.budgetWarningEnabled` /
/// `.budgetWarningThreshold` keys.
extension PlanningClient: DependencyKey {
    public static var liveValue: PlanningClient {
        let budgetStore = SwiftDataStore<Budget, SDBudget>()
        let transactionStore = SwiftDataStore<Transaction, SDTransaction>()
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
                let (start, end) = currentPeriodBounds(for: budget.period, today: Date())
                let all = try await transactionStore.fetchAll()
                let inPeriod = all.filter { txn in
                    guard (start...end).contains(txn.date) else { return false }
                    guard txn.type == .expense else { return false }
                    guard let scopedCategoryId = budget.categoryId else { return true }
                    return txn.categoryId == scopedCategoryId
                }
                let spent = inPeriod.reduce(Decimal.zero) { $0 + $1.amount }
                return BudgetStatus(
                    budget: budget,
                    periodStart: start,
                    periodEnd: end,
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
                    let (start, end) = currentPeriodBounds(for: budget.period, today: today)
                    let inPeriod = all.filter { (start...end).contains($0.date) }

                    let formatter = ISO8601DateFormatter()
                    formatter.formatOptions = [.withFullDate]
                    let pKey = formatter.string(from: start)
                    let bidStr = budget.id.uuidString
                    let lastWarned = notificationAdapter.lastWarnedPercent(bidStr, pKey)

                    let outcome = BudgetWarningPolicy.evaluate(
                        budget: budget,
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

/// Compute the calendar-aligned period bounds for the given `BudgetPeriod`
/// containing `today`. Returns a closed range — `end` is the last
/// representable instant of the period (DateInterval.end minus 1 ms) so
/// the resulting `ClosedRange<Date>` excludes the next period's start.
private func currentPeriodBounds(for period: BudgetPeriod, today: Date) -> (start: Date, end: Date) {
    let cal = Calendar.current
    let component: Calendar.Component
    switch period {
    case .weekly:  component = .weekOfYear
    case .monthly: component = .month
    case .yearly:  component = .year
    }
    let interval = cal.dateInterval(of: component, for: today) ?? DateInterval(start: today, duration: 0)
    return (interval.start, interval.end.addingTimeInterval(-0.001))
}
