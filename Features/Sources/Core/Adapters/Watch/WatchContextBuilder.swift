import Foundation
import SwiftData
import Dependencies
import Domain

/// Aggregates the data the watchOS app needs from the iPhone-side
/// SwiftData store into a single `WatchContextSnapshot`. Used by
/// `WatchSyncObserver` (push on data change) and at app launch (initial
/// push).
public enum WatchContextBuilder {

    public static func build(
        now: Date = Date(),
        defaultAccountId: Account.ID
    ) async throws -> WatchContextSnapshot {
        @Dependency(\.calendar) var calendar
        @Dependency(\.planningClient) var planningClient

        // Infrastructure-layer collaborator in the Watch sync pipeline:
        // reads SwiftData directly via `SwiftDataStore` (same-layer, legal —
        // see docs/architecture.md §10). Behaviour mirrors the former
        // categoryClient/accountClient/transactionClient `fetchAll`/`fetchActive`
        // closures (identical sort + active filter). `planningClient.listActive`
        // stays as a dependency — it crosses into the Application layer.
        let categoryStore = SwiftDataStore<Domain.Category, SDCategory>()
        let accountStore = SwiftDataStore<Account, SDAccount>()
        let transactionStore = SwiftDataStore<Transaction, SDTransaction>()

        let categories = try await categoryStore.fetchAll(sortBy: [SortDescriptor(\.sortOrder)])
        let accounts = try await accountStore.fetchAll(sortBy: [SortDescriptor(\.sortOrder)])
            .filter { !$0.isArchived }
        let allTxns = try await transactionStore.fetchAll(sortBy: [SortDescriptor(\.date, order: .reverse)])
        let activeBudgets = try await planningClient.listActive()

        let startOfToday = calendar.startOfDay(for: now)
        guard let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) else {
            throw CoreError.operationDenied("Failed to compute start of tomorrow")
        }
        let todayRange = startOfToday..<startOfTomorrow

        let todayExpenses = allTxns.filter {
            $0.type == .expense && todayRange.contains($0.date)
        }
        let todayTotal = todayExpenses.reduce(Decimal(0)) { $0 + $1.amount }

        let progress = monthBudgetProgress(
            now: now,
            calendar: calendar,
            transactions: allTxns,
            budgets: activeBudgets
        )

        return WatchContextSnapshot(
            categories: categories,
            accounts: accounts,
            defaultAccountId: defaultAccountId,
            todayTotal: todayTotal,
            todayCount: todayExpenses.count,
            monthBudgetProgress: progress,
            snapshotAt: now
        )
    }

    /// Returns the share of the active *uncategorized monthly* budget
    /// consumed so far this month, or `nil` if no such budget is active.
    /// Watch UI only surfaces this as the Corner Complication gauge — the
    /// minimum sufficient signal.
    private static func monthBudgetProgress(
        now: Date,
        calendar: Calendar,
        transactions: [Transaction],
        budgets: [Budget]
    ) -> Double? {
        guard let overall = budgets.first(where: {
            $0.period == .monthly && $0.categoryId == nil
        }) else { return nil }

        let components = calendar.dateComponents([.year, .month], from: now)
        guard let startOfMonth = calendar.date(from: components),
              let startOfNextMonth = calendar.date(
                byAdding: .month, value: 1, to: startOfMonth
              ) else { return nil }
        let monthRange = startOfMonth..<startOfNextMonth

        let monthExpenseTotal = transactions
            .filter { $0.type == .expense && monthRange.contains($0.date) }
            .reduce(Decimal(0)) { $0 + $1.amount }

        guard overall.amount > 0 else { return nil }
        let ratio = (monthExpenseTotal as NSDecimalNumber).doubleValue
               / (overall.amount as NSDecimalNumber).doubleValue
        return ratio
    }
}
