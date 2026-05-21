import Foundation
import Dependencies
import Domain

extension BudgetUseCase: DependencyKey {
    public static var liveValue: BudgetUseCase {
        @Dependency(\.budgetClient) var budgetClient
        @Dependency(\.transactionClient) var transactionClient
        @Dependency(\.notificationAdapter) var notificationAdapter
        @Dependency(\.userSettingsAdapter) var userSettingsAdapter

        return BudgetUseCase(
            listActive: { try await budgetClient.fetchActive() },
            create: { try await budgetClient.add($0) },
            update: { try await budgetClient.update($0) },
            delete: { try await budgetClient.delete($0) },
            currentStatus: { budget in
                let (start, end) = currentPeriodBounds(for: budget.period, today: Date())
                let filter = TransactionFilter(
                    categoryIds: budget.categoryId.map { Set([$0]) },
                    types: [.expense],
                    dateRange: start...end
                )
                let inPeriod = try await transactionClient.fetch(filter)
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
                // re-fetches all in-period transactions (same as the previous
                // `TransactionClient+Live.checkBudgetWarnings` did). Phase 5
                // can optimise to "did this transaction's category match any
                // active budget" if profiling flags it; until then, the brute
                // re-scan keeps behaviour identical to the original.

                guard userSettingsAdapter.bool(.budgetWarningEnabled) else { return }
                let threshold = userSettingsAdapter.int(.budgetWarningThreshold)
                guard let activeBudgets = try? await budgetClient.fetchActive() else { return }

                let today = Date()
                for budget in activeBudgets {
                    let (start, end) = currentPeriodBounds(for: budget.period, today: today)
                    let filter = TransactionFilter(dateRange: start...end)
                    guard let inPeriod = try? await transactionClient.fetch(filter) else { continue }

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
