import Foundation
import SwiftData
import Dependencies
import Domain

/// A TCA dependency that provides access to the SwiftData `ModelContainer`.
///
/// Use `DatabaseClient` to obtain the shared `ModelContainer` from which
/// live client implementations derive their `ModelContext` instances.
///
/// ```swift
/// @Dependency(\.databaseClient) var databaseClient
/// let container = databaseClient.modelContainer()
/// ```
public struct DatabaseClient: Sendable {
    /// Returns the configured `ModelContainer` for the application.
    public var modelContainer: @Sendable () -> ModelContainer

    public init(modelContainer: @escaping @Sendable () -> ModelContainer) {
        self.modelContainer = modelContainer
    }
}

// MARK: - Live Value

extension DatabaseClient: DependencyKey {
    public static let schema = Schema([
        SDTransaction.self,
        SDAccount.self,
        SDCategory.self,
        SDBudget.self,
        SDTag.self,
        SDRecurringTransaction.self,
        SDCarrier.self,
    ])

    /// App Group identifier shared between the main app and widget extension.
    /// Both local and CloudKit-backed configurations point their store at the
    /// same URL inside this container so toggling sync never moves the file.
    private static let appGroupID = "group.com.drake.NeuLedger"

    /// Shared SwiftData store URL inside the app group container.
    /// Falling back to the per-app Application Support directory keeps the
    /// app runnable even if the entitlement is misconfigured (the data won't
    /// be reachable by the widget in that case, but the main app still works).
    private static let storeURL: URL = {
        let filename = "default.store"
        if let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) {
            let dir = groupURL.appending(path: "Library/Application Support", directoryHint: .isDirectory)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            return dir.appending(path: filename, directoryHint: .notDirectory)
        }
        let fallback = URL.applicationSupportDirectory
        try? FileManager.default.createDirectory(at: fallback, withIntermediateDirectories: true)
        return fallback.appending(path: filename, directoryHint: .notDirectory)
    }()

    private static let localConfiguration = ModelConfiguration(
        schema: schema,
        url: storeURL,
        cloudKitDatabase: .none
    )

    public static let cloudConfiguration = ModelConfiguration(
        schema: schema,
        url: storeURL,
        cloudKitDatabase: .private("iCloud.com.drake.NeuLedger")
    )

    /// Shared live container. On launch, restores the CloudKit-backed container if sync was
    /// previously enabled. Replaced at runtime by SyncClient during the migration flow.
    nonisolated(unsafe) public static var container: ModelContainer = {
        do {
            // Read raw UserDefaults directly here (rather than via UserSettingsClient)
            // because this static initializer runs before TCA dependencies resolve.
            // Use SettingsKey.rawValue as the single source of truth for the key.
            let isSyncEnabled = UserDefaults.standard.bool(forKey: SettingsKey<Bool>.isSyncEnabled.rawValue)
            let isCloudKitAvailable = FileManager.default.ubiquityIdentityToken != nil

            if isSyncEnabled && isCloudKitAvailable {
                return try ModelContainer(for: schema, configurations: [cloudConfiguration])
            } else {
                let c = try ModelContainer(for: schema, configurations: [localConfiguration])
                seedIfNeeded(in: ModelContext(c))
                return c
            }
        } catch {
            fatalError("Failed to create live ModelContainer: \(error)")
        }
    }()

    public static let liveValue = DatabaseClient(
        modelContainer: { DatabaseClient.container }
    )

    /// In-memory `ModelContainer` shared by `DatabaseClient.testValue` and
    /// `\.modelContainer`'s testValue. Created once per process so tests
    /// running in the same target share seeded default data.
    nonisolated(unsafe) public static let testContainer: ModelContainer = {
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            seedIfNeeded(in: ModelContext(container))
            return container
        } catch {
            fatalError("Failed to create test ModelContainer: \(error)")
        }
    }()

    /// An in-memory `DatabaseClient` suitable for unit tests.
    public static let testValue = DatabaseClient(
        modelContainer: { DatabaseClient.testContainer }
    )
}

// MARK: - DatabaseClient Helpers
extension DatabaseClient {

    // MARK: Context

    /// Creates a new `ModelContext` from the shared `ModelContainer`.
    func makeContext() -> ModelContext {
        ModelContext(modelContainer())
    }

    // MARK: Fetch

    /// Fetches persistence models matching the given descriptor and maps them to domain values.
    func fetch<T: PersistentDomainModel>(
        _ descriptor: FetchDescriptor<T>
    ) throws -> [T.DomainModel] {
        let context = makeContext()
        return try context.fetch(descriptor).map { $0.toDomain() }
    }

    // MARK: Add

    /// Inserts a new persistence model created from the given domain value and saves.
    func add<T: PersistentDomainModel>(
        _ domain: T.DomainModel,
        as type: T.Type
    ) throws {
        let context = makeContext()
        T.from(domain, context: context)
        try context.save()
    }

    // MARK: Update

    /// Fetches a single model matching the descriptor, applies a mutation closure, and saves.
    ///
    /// The `mutation` closure receives both the fetched model and its `ModelContext`.
    /// The context is provided for operations that need to resolve related objects
    /// (e.g. `SDTag.resolve(_:context:)`) — most callers can ignore it with `_`.
    ///
    /// - Throws: `CoreError.notFound` if no matching entity exists.
    func update<T: PersistentModel>(
        matching descriptor: FetchDescriptor<T>,
        mutation: (T, ModelContext) throws -> Void
    ) throws {
        let context = makeContext()
        var bounded = descriptor
        bounded.fetchLimit = 1
        guard let existing = try context.fetch(bounded).first else {
            throw CoreError.notFound("\(T.self)")
        }
        try mutation(existing, context)
        try context.save()
    }

    // MARK: Aggregates

    /// Returns the per-day expense sums for the most recent `days` days, ordered
    /// oldest -> newest. Index `days - 1` is today.
    ///
    /// - Parameters:
    ///   - accountID: Optional. When provided, only transactions on that account are summed.
    ///   - days: Number of buckets to return (must be >= 1).
    func weeklySpendingSums(accountID: UUID?, days: Int) throws -> [Decimal] {
        guard days >= 1 else { return [] }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let earliest = cal.date(byAdding: .day, value: -(days - 1), to: today) else {
            return Array(repeating: 0, count: days)
        }

        let typeRaw = TransactionType.expense.rawValue
        let predicate = #Predicate<SDTransaction> { tx in
            tx.type == typeRaw && tx.date >= earliest
        }
        var descriptor = FetchDescriptor<SDTransaction>(predicate: predicate)
        descriptor.sortBy = [SortDescriptor(\.date)]
        let context = makeContext()
        let rows = try context.fetch(descriptor)

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

    /// Returns today's expense total, the last 7 days' expense total, and the
    /// savings ratio over the same 7-day window.
    ///
    /// Savings ratio = max(0, (income - expense) / income), clamped to 0 when
    /// income is 0.
    func statsSnapshot() throws -> StatsSnapshot {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let weekStart = cal.date(byAdding: .day, value: -6, to: today) else {
            return .zero
        }
        let predicate = #Predicate<SDTransaction> { tx in
            tx.date >= weekStart
        }
        let descriptor = FetchDescriptor<SDTransaction>(predicate: predicate)
        let context = makeContext()
        let rows = try context.fetch(descriptor)

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

    /// Computes a `TransactionInsight` for the given transaction.
    ///
    /// - `.expense` with categoryId → average + count + total of that category
    ///   in the current calendar month.
    /// - `.income` with categoryId → most recent prior amount + monthly count
    ///   + monthly net.
    /// - `.transfer` → monthly transfer count + total.
    /// - Anything else → `.fallback(monthlyCategoryCount:)`.
    func detailStats(for transaction: Transaction) throws -> TransactionInsight {
        let cal = Calendar.current
        let now = Date()
        guard let monthRange = cal.dateInterval(of: .month, for: now) else {
            return TransactionInsight(kind: .fallback(monthlyCategoryCount: 0))
        }
        let monthStart = monthRange.start
        let monthEnd = monthRange.end

        let descriptor = FetchDescriptor<SDTransaction>(
            predicate: #Predicate<SDTransaction> { tx in
                tx.date >= monthStart && tx.date < monthEnd
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let context = makeContext()
        let monthRows = try context.fetch(descriptor)

        switch transaction.type {
        case .expense:
            guard let catId = transaction.categoryId else {
                return TransactionInsight(kind: .fallback(monthlyCategoryCount: 1))
            }
            let sameCategory = monthRows.filter { $0.type == TransactionType.expense.rawValue && $0.categoryId == catId }
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
            let sameCategory = monthRows.filter { $0.type == TransactionType.income.rawValue && $0.categoryId == catId }
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

    // MARK: Delete

    /// Fetches a single model matching the descriptor, optionally validates it, deletes it, and saves.
    ///
    /// - Parameters:
    ///   - descriptor: A `FetchDescriptor` that should match exactly one entity.
    ///   - validation: An optional closure to validate the entity before deletion.
    ///                 Throwing from this closure cancels the delete.
    /// - Throws: `CoreError.notFound` if no matching entity exists; re-throws any error from `validation`.
    func deleteFirst<T: PersistentModel>(
        matching descriptor: FetchDescriptor<T>,
        validation: ((T) throws -> Void)? = nil
    ) throws {
        let context = makeContext()
        var bounded = descriptor
        bounded.fetchLimit = 1
        guard let existing = try context.fetch(bounded).first else {
            throw CoreError.notFound("\(T.self)")
        }
        try validation?(existing)
        context.delete(existing)
        try context.save()
    }
}

// MARK: - DependencyValues Registration

public extension DependencyValues {
    /// The database client providing access to the SwiftData `ModelContainer`.
    var databaseClient: DatabaseClient {
        get { self[DatabaseClient.self] }
        set { self[DatabaseClient.self] = newValue }
    }
}

// MARK: - Seed Data
struct SeedCategory {
    let name: String
    let icon: String
    let color: String
}

extension SeedCategory {
    static var food: SeedCategory {
        SeedCategory(name: "Food", icon: "fork.knife", color: "#FF6B6B")
    }
    
    static var transport: SeedCategory {
        SeedCategory(name: "Transport", icon: "car.fill", color: "#4ECDC4")
    }
    
    static var entertainment: SeedCategory {
        SeedCategory(name: "Entertainment", icon: "gamecontroller.fill", color: "#45B7D1")
    }
    
    static var shopping: SeedCategory {
        SeedCategory(name: "Shopping", icon: "bag.fill", color: "#96CEB4")
    }
    
    static var housing: SeedCategory {
        SeedCategory(name: "Housing", icon: "house.fill", color: "#FFEAA7")
    }
    
    static var utilities: SeedCategory {
        SeedCategory(name: "Utilities", icon: "bolt.fill", color: "#DDA0DD")
    }
    
    static var health: SeedCategory {
        SeedCategory(name: "Health", icon: "heart.fill", color: "#FF6B9D")
    }
    
    static var education: SeedCategory {
        SeedCategory(name: "Education", icon: "book.fill", color: "#C9B1FF")
    }
    
    static var otherExpense: SeedCategory {
        SeedCategory(name: "Other Expense", icon: "ellipsis.circle.fill", color: "#95A5A6")
    }
    
    static var salary: SeedCategory {
        SeedCategory(name: "Salary", icon: "banknote.fill", color: "#2ECC71")
    }
    
    static var freelance: SeedCategory {
        SeedCategory(name: "Freelance", icon: "laptopcomputer", color: "#3498DB")
    }
    
    static var investment: SeedCategory {
        SeedCategory(name: "Investment", icon: "chart.line.uptrend.xyaxis", color: "#F39C12")
    }
    
    static var gift: SeedCategory {
        SeedCategory(name: "Gift", icon: "gift.fill", color: "#E74C3C")
    }
    
    static var otherIncome: SeedCategory {
        SeedCategory(name: "Other Income", icon: "ellipsis.circle.fill", color: "#1ABC9C")
    }
    static var defaultExpenseCategories: [SeedCategory] {
        [.food, .transport, .entertainment, .shopping, .housing, .utilities, .health, .education, .otherExpense]
    }
    static var defaultIncomeCategories: [SeedCategory] {
        [.salary, .freelance, .investment, .gift, .otherIncome]
    }
}



// MARK: - Seeding

private extension DatabaseClient {
    static func seedIfNeeded(in context: ModelContext) {
        do {
            guard try context.fetchCount(FetchDescriptor<SDCategory>()) == 0 else { return }

            for (index, seed) in SeedCategory.defaultExpenseCategories.enumerated() {
                context.insert(SDCategory(
                    id: UUID(), name: seed.name, icon: seed.icon, color: seed.color,
                    type: TransactionType.expense.rawValue, sortOrder: index, isDefault: true
                ))
            }

            for (index, seed) in SeedCategory.defaultIncomeCategories.enumerated() {
                context.insert(SDCategory(
                    id: UUID(), name: seed.name, icon: seed.icon, color: seed.color,
                    type: TransactionType.income.rawValue, sortOrder: index, isDefault: true
                ))
            }

            try context.save()
        } catch {
            print("Failed to seed default data: \(error)")
        }
    }
}
