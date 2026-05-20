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
                    let cal = Calendar.current
                    let component: Calendar.Component
                    switch budget.period {
                    case .weekly:  component = .weekOfYear
                    case .monthly: component = .month
                    case .yearly:  component = .year
                    }
                    guard let interval = cal.dateInterval(of: component, for: today) else { continue }

                    // DateInterval.end is exclusive — subtract 1ms so the
                    // ClosedRange excludes the next period's start.
                    let periodRange = interval.start...interval.end.addingTimeInterval(-0.001)
                    let filter = TransactionFilter(dateRange: periodRange)
                    guard let inPeriod = try? await transactionClient.fetch(filter) else { continue }

                    let formatter = ISO8601DateFormatter()
                    formatter.formatOptions = [.withFullDate]
                    let pKey = formatter.string(from: interval.start)
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
