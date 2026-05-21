import Foundation
import SwiftData
import Domain

/// Module-internal aggregation kernels used by both
/// `AnalyticsUseCase+Live` (the architectural target) and
/// `TransactionClient+Live` (the legacy Repository surface kept alive
/// during Phase 5 for compatibility). Phase 6 removes
/// `TransactionClient`'s three stats endpoints; this kernel stays as
/// the single source of truth for the underlying SwiftData reads.
///
/// All methods read from a *fresh* `ModelContext` derived from the
/// shared container. SwiftData rows never escape this file's helpers
/// — callers receive domain types only.
enum TransactionAnalyticsKernel {
    // MARK: - Public entry points

    /// Per-day expense sums for the most recent `days` days ending on
    /// today, optionally scoped to a single account.
    static func weeklySpending(
        accountID: UUID?,
        days: Int,
        container: ModelContainer
    ) throws -> [Decimal] {
        guard days >= 1 else { return [] }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let earliest = cal.date(byAdding: .day, value: -(days - 1), to: today) else {
            return Array(repeating: 0, count: days)
        }
        let typeRaw = TransactionType.expense.rawValue
        let rows = try fetch(
            container: container,
            predicate: #Predicate<SDTransaction> { tx in
                tx.type == typeRaw && tx.date >= earliest
            },
            sortBy: [SortDescriptor(\.date)]
        )
        var buckets = Array(repeating: Decimal(0), count: days)
        for tx in rows {
            if let aid = accountID, tx.accountId != aid { continue }
            let dayStart = cal.startOfDay(for: tx.date)
            let dayOffset = cal.dateComponents([.day], from: dayStart, to: today).day ?? 0
            let index = (days - 1) - dayOffset
            guard index >= 0 && index < days else { continue }
            buckets[index] += tx.amount
        }
        return buckets
    }

    /// Today's expense + last-7-days expense + 7-day savings ratio
    /// anchored to `referenceDate`.
    static func statsSnapshot(
        referenceDate: Date,
        container: ModelContainer
    ) throws -> StatsSnapshot {
        let cal = Calendar.current
        let today = cal.startOfDay(for: referenceDate)
        guard let weekStart = cal.date(byAdding: .day, value: -6, to: today) else {
            return .zero
        }
        let rows = try fetch(
            container: container,
            predicate: #Predicate<SDTransaction> { tx in tx.date >= weekStart },
            sortBy: []
        )
        var todayTotal: Decimal = 0
        var weekTotal: Decimal = 0
        var income: Decimal = 0
        var expense: Decimal = 0
        let expenseRaw = TransactionType.expense.rawValue
        let incomeRaw = TransactionType.income.rawValue
        for tx in rows {
            if tx.type == expenseRaw {
                weekTotal += tx.amount
                expense += tx.amount
                if cal.isDate(tx.date, inSameDayAs: today) {
                    todayTotal += tx.amount
                }
            } else if tx.type == incomeRaw {
                income += tx.amount
            }
        }
        let savings: Double
        if income > 0 {
            let saved = NSDecimalNumber(decimal: income - expense).doubleValue
            let inc = NSDecimalNumber(decimal: income).doubleValue
            savings = max(0, saved / inc)
        } else {
            savings = 0
        }
        return StatsSnapshot(today: todayTotal, week: weekTotal, savingsPercentage: savings)
    }

    /// Same-category monthly average / prior amount / transfer
    /// activity context for a single transaction.
    static func detailStats(
        for transaction: Transaction,
        container: ModelContainer
    ) throws -> TransactionInsight {
        let cal = Calendar.current
        let now = Date()
        guard let monthRange = cal.dateInterval(of: .month, for: now) else {
            return TransactionInsight(kind: .fallback(monthlyCategoryCount: 0))
        }
        let monthStart = monthRange.start
        let monthEnd = monthRange.end
        let monthRows = try fetch(
            container: container,
            predicate: #Predicate<SDTransaction> { tx in
                tx.date >= monthStart && tx.date < monthEnd
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )

        switch transaction.type {
        case .expense:
            guard let catId = transaction.categoryId else {
                return TransactionInsight(kind: .fallback(monthlyCategoryCount: 1))
            }
            let sameCategory = monthRows.filter {
                $0.type == TransactionType.expense.rawValue && $0.categoryId == catId
            }
            let count = sameCategory.count
            let total = sameCategory.reduce(Decimal(0)) { $0 + $1.amount }
            let avg: Decimal = count > 0 ? total / Decimal(count) : 0
            let avgDouble = NSDecimalNumber(decimal: avg).doubleValue
            let amtDouble = NSDecimalNumber(decimal: transaction.amount).doubleValue
            let percentDelta: Double = avgDouble > 0 ? (amtDouble - avgDouble) / avgDouble * 100 : 0
            return TransactionInsight(kind: .expenseVsCategoryAvg(
                percentDelta: percentDelta,
                avg: avg,
                monthlyCount: count,
                monthTotal: total
            ))

        case .income:
            guard let catId = transaction.categoryId else {
                return TransactionInsight(kind: .fallback(monthlyCategoryCount: 1))
            }
            let sameCategory = monthRows.filter {
                $0.type == TransactionType.income.rawValue && $0.categoryId == catId
            }
            let count = sameCategory.count
            let prior = sameCategory.first(where: { $0.id != transaction.id })
            let lastAmount: Decimal = prior?.amount ?? transaction.amount
            let lastDouble = NSDecimalNumber(decimal: lastAmount).doubleValue
            let amtDouble = NSDecimalNumber(decimal: transaction.amount).doubleValue
            let percentDelta: Double = lastDouble > 0 ? (amtDouble - lastDouble) / lastDouble * 100 : 0
            let monthIncome = monthRows
                .filter { $0.type == TransactionType.income.rawValue }
                .reduce(Decimal(0)) { $0 + $1.amount }
            let monthExpense = monthRows
                .filter { $0.type == TransactionType.expense.rawValue }
                .reduce(Decimal(0)) { $0 + $1.amount }
            return TransactionInsight(kind: .incomeVsLast(
                percentDelta: percentDelta,
                lastAmount: lastAmount,
                monthlyCount: count,
                netMonth: monthIncome - monthExpense
            ))

        case .transfer:
            let transfers = monthRows.filter { $0.type == TransactionType.transfer.rawValue }
            let total = transfers.reduce(Decimal(0)) { $0 + $1.amount }
            return TransactionInsight(kind: .transfer(monthCount: transfers.count, monthTotal: total))
        }
    }

    /// Per-day expense bars over an arbitrary interval. Days with no
    /// expenses are omitted.
    static func dailyBars(
        range: DateInterval,
        container: ModelContainer
    ) throws -> [DailyTrend] {
        let cal = Calendar.current
        let start = range.start
        let end = range.end
        let typeRaw = TransactionType.expense.rawValue
        let rows = try fetch(
            container: container,
            predicate: #Predicate<SDTransaction> { tx in
                tx.type == typeRaw && tx.date >= start && tx.date < end
            },
            sortBy: [SortDescriptor(\.date)]
        )
        var sums: [Date: Decimal] = [:]
        for tx in rows {
            let day = cal.startOfDay(for: tx.date)
            sums[day, default: 0] += tx.amount
        }
        return sums
            .map { DailyTrend(date: $0.key, amount: $0.value) }
            .sorted(by: { $0.date < $1.date })
    }

    /// Category-share rollup over an arbitrary interval, sorted by
    /// amount descending. Transactions with no category fall into a
    /// single "—" bucket.
    static func categoryProportions(
        range: DateInterval,
        container: ModelContainer,
        categoryNamesById: [UUID: String]
    ) throws -> [CategoryProportion] {
        let start = range.start
        let end = range.end
        let typeRaw = TransactionType.expense.rawValue
        let rows = try fetch(
            container: container,
            predicate: #Predicate<SDTransaction> { tx in
                tx.type == typeRaw && tx.date >= start && tx.date < end
            },
            sortBy: []
        )

        var sums: [UUID: Decimal] = [:]
        var unassigned: Decimal = 0
        for tx in rows {
            if let catId = tx.categoryId {
                sums[catId, default: 0] += tx.amount
            } else {
                unassigned += tx.amount
            }
        }
        var result = sums.map { id, amount in
            CategoryProportion(
                id: id.uuidString,
                name: categoryNamesById[id] ?? id.uuidString,
                amount: amount
            )
        }
        if unassigned > 0 {
            result.append(CategoryProportion(name: "—", amount: unassigned))
        }
        return result.sorted(by: { $0.amount > $1.amount })
    }

    /// Gauge-ready metrics for active budgets, optionally narrowed to
    /// categories that appear in `accountId`'s recent expenses.
    static func budgetGauges(
        accountId: UUID?,
        activeBudgets: [Budget],
        categoryNamesById: [UUID: String],
        container: ModelContainer
    ) throws -> [BudgetGaugeMetrics] {
        guard !activeBudgets.isEmpty else { return [] }

        var filteredBudgets = activeBudgets
        if let accountId {
            let typeRaw = TransactionType.expense.rawValue
            let rows = try fetch(
                container: container,
                predicate: #Predicate<SDTransaction> { tx in
                    tx.type == typeRaw && tx.accountId == accountId
                },
                sortBy: []
            )
            let relevant = Set(rows.compactMap { $0.categoryId })
            filteredBudgets = activeBudgets.filter { budget in
                guard let catId = budget.categoryId else { return true }
                return relevant.contains(catId)
            }
        }

        var metrics: [BudgetGaugeMetrics] = []
        for budget in filteredBudgets {
            let (periodStart, periodEnd) = currentPeriodRange(for: budget.period)
            let typeRaw = TransactionType.expense.rawValue
            let rows = try fetch(
                container: container,
                predicate: #Predicate<SDTransaction> { tx in
                    tx.type == typeRaw
                        && tx.date >= periodStart
                        && tx.date <= periodEnd
                },
                sortBy: []
            )
            let categoryFilter = budget.categoryId
            let scoped = rows.filter { tx in
                guard let catId = categoryFilter else { return true }
                return tx.categoryId == catId
            }
            let spent = scoped.reduce(Decimal.zero) { $0 + $1.amount }

            let label: String
            if let catId = budget.categoryId, let name = categoryNamesById[catId] {
                label = name
            } else {
                label = budget.name
            }
            metrics.append(BudgetGaugeMetrics(
                id: budget.id.uuidString,
                categoryName: label,
                spentAmount: spent,
                totalBudget: budget.amount
            ))
        }
        return metrics
    }

    // MARK: - Internals

    private static func fetch(
        container: ModelContainer,
        predicate: Predicate<SDTransaction>,
        sortBy: [SortDescriptor<SDTransaction>]
    ) throws -> [SDTransaction] {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<SDTransaction>(predicate: predicate)
        descriptor.sortBy = sortBy
        return try context.fetch(descriptor)
    }
}

/// Calendar-aligned period bounds for `BudgetPeriod` containing today.
/// Returns inclusive start...end pair (end - 1ms).
private func currentPeriodRange(for period: BudgetPeriod) -> (start: Date, end: Date) {
    let cal = Calendar.current
    let component: Calendar.Component
    switch period {
    case .weekly:  component = .weekOfYear
    case .monthly: component = .month
    case .yearly:  component = .year
    }
    let interval = cal.dateInterval(of: component, for: Date()) ?? DateInterval(start: Date(), duration: 0)
    return (interval.start, interval.end.addingTimeInterval(-0.001))
}
