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
        accountID: Account.ID?,
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
        // 沒有收入就沒有分母，儲蓄率無從定義——回 `nil` 而不是 0，讓畫面能把
        // 「這期沒有收入」跟「這期剛好收支相抵」分開講。
        //
        // 也不再 `max(0, ...)`：夾制會把入不敷出的人的儲蓄率壓成 0，而 0 在
        // `InsightComposer` 眼中等同「沒資料」，結果是**最需要看到這個數字的人
        // 反而完全看不到那張卡**。負值照實回傳。
        let savings: Double?
        if income > 0 {
            let saved = NSDecimalNumber(decimal: income - expense).doubleValue
            let inc = NSDecimalNumber(decimal: income).doubleValue
            savings = saved / inc
        } else {
            savings = nil
        }
        return StatsSnapshot(today: todayTotal, week: weekTotal, savingsPercentage: savings)
    }

    /// 區間內收入 / 支出總額（排除轉帳），可限定帳戶。
    static func financialSummary(
        range: DateInterval,
        accountId: Account.ID?,
        container: ModelContainer
    ) throws -> FinancialSummary {
        let start = range.start
        let end = range.end
        let rows = try fetch(
            container: container,
            predicate: #Predicate<SDTransaction> { tx in tx.date >= start && tx.date < end },
            sortBy: []
        )
        let scoped = rows.map(scalarTransaction).filter { tx in
            // 單向比對，與 `dailyBars` / `categoryProportions` 同一種拼法。
            //
            // 一筆收入／支出在語意上屬於它的**來源**帳戶，不屬於一個殘留的目的欄位。
            // 用 `involves(account:)` 會把「支出卻帶著 toAccountId」的格式錯誤列算進
            // 目的帳戶，而圓餅圖與長條圖是單向的 → 同一頁會出現「本月支出 NT$500」
            // 配一張空圓餅圖。那種列的根因在 `AddTransactionFeature.typeChanged`
            // 沒有清掉 `toAccountId`（另開 follow-up），這裡先不讓它污染 KPI。
            accountId.map { tx.accountId == $0 } ?? true
        }
        return FinancialSummary(
            totalIncome: scoped.total(of: .income),
            totalExpense: scoped.total(of: .expense)
        )
    }

    /// Same-category monthly average / prior amount / transfer
    /// activity context for a single transaction.
    static func detailStats(
        for transaction: Transaction,
        container: ModelContainer
    ) throws -> TransactionInsight {
        let cal = Calendar.current
        let now = Date()
        // 走 `BudgetPeriod` 的唯一定義，不自行 `dateInterval(of: .month,...)`
        // （spec §5 的驗收條件）。原本那個 `guard let ... else { return .fallback }`
        // 是死路徑——Gregorian calendar 對任何合法日期都有所屬月份，而
        // `BudgetPeriod.dateInterval(containing:)` 自己也有零長度 fallback，
        // 所以兩者行為等價。
        let monthRange = BudgetPeriod.monthly.dateInterval(containing: now, calendar: cal)
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
    /// expenses are omitted. Optionally scoped to a single account.
    static func dailyBars(
        range: DateInterval,
        accountId: Account.ID?,
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
            if let accountId, tx.accountId != accountId { continue }
            let day = cal.startOfDay(for: tx.date)
            sums[day, default: 0] += tx.amount
        }
        return sums
            .map { DailyTrend(date: $0.key, amount: $0.value) }
            .sorted(by: { $0.date < $1.date })
    }

    /// Category-share rollup over an arbitrary interval, sorted by
    /// amount descending. Transactions with no category fall into a
    /// single unassigned bucket (`CategoryProportion.uncategorizedId`).
    /// Optionally scoped to a single account.
    static func categoryProportions(
        range: DateInterval,
        accountId: Account.ID?,
        container: ModelContainer,
        categoryNamesById: [UUID: String],
        unassignedName: String
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
            if let accountId, tx.accountId != accountId { continue }
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
            // 標記成未分類：呼叫端（Dashboard 的「最大支出分類」）要能跳過這一桶，
            // 而不必去比對顯示字串（該字串現在也走在地化，見 `unassignedName`）。
            result.append(CategoryProportion(
                id: CategoryProportion.uncategorizedId,
                name: unassignedName,
                amount: unassigned,
                isUnassigned: true
            ))
        }
        return result.sorted(by: { $0.amount > $1.amount })
    }

    /// Gauge-ready metrics for active budgets, optionally narrowed to
    /// categories that appear in `accountId`'s recent expenses.
    static func budgetGauges(
        accountId: Account.ID?,
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
            let interval = budget.period.dateInterval(containing: Date())
            let periodStart = interval.start
            let periodEnd = interval.end
            let typeRaw = TransactionType.expense.rawValue
            let rows = try fetch(
                container: container,
                predicate: #Predicate<SDTransaction> { tx in
                    tx.type == typeRaw
                        && tx.date >= periodStart
                        && tx.date < periodEnd
                },
                sortBy: []
            )
            let spent = budget.spent(in: rows.map(scalarTransaction))

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

    /// 只讀純量欄位的 Domain 投影（不碰 `tags` 關聯），給 `Budget.spent(in:)` /
    /// `Transaction.involves(account:)` 等 Domain 規則使用。
    /// 欄位對照 `Core/Mappers/SDTransaction+Mapping.swift` 的 `toDomain()`；
    /// `SDTransaction` 新增純量欄位時兩處要一起改。
    private static func scalarTransaction(_ tx: SDTransaction) -> Transaction {
        Transaction(
            id: tx.id,
            amount: tx.amount,
            date: tx.date,
            note: tx.note,
            categoryId: tx.categoryId,
            accountId: tx.accountId,
            toAccountId: tx.toAccountId,
            type: TransactionType(rawValue: tx.type) ?? .expense,
            tags: [],
            aiSuggested: tx.aiSuggested,
            createdAt: tx.createdAt,
            updatedAt: tx.updatedAt
        )
    }

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
