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
    /// The production `ModelContainer` using on-disk persistent storage.
    public static let liveValue: DatabaseClient = {
        let schema = Schema([
            SDTransaction.self,
            SDAccount.self,
            SDCategory.self,
            SDBudget.self,
            SDTag.self,
        ])
        let configuration = ModelConfiguration(schema: schema)
        let container: ModelContainer
        do {
            container = try ModelContainer(for: schema, configurations: [configuration])
            let context = ModelContext(container)
            seedIfNeeded(in: context)
        } catch {
            fatalError("Failed to create live ModelContainer: \(error)")
        }
        return DatabaseClient(
            modelContainer: { container }
        )
    }()

    /// An in-memory `ModelContainer` suitable for unit tests.
    public static let testValue: DatabaseClient = {
        let schema = Schema([
            SDTransaction.self,
            SDAccount.self,
            SDCategory.self,
            SDBudget.self,
            SDTag.self,
        ])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        let container: ModelContainer
        do {
            container = try ModelContainer(for: schema, configurations: [configuration])
            let context = ModelContext(container)
            seedIfNeeded(in: context)
        } catch {
            fatalError("Failed to create test ModelContainer: \(error)")
        }
        return DatabaseClient(
            modelContainer: { container }
        )
    }()
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
    func fetch<T: DomainConvertible>(
        _ descriptor: FetchDescriptor<T>
    ) throws -> [T.DomainModel] {
        let context = makeContext()
        return try context.fetch(descriptor).map { $0.toDomain() }
    }

    // MARK: Add

    /// Inserts a new persistence model created from the given domain value and saves.
    func add<T: DomainConvertible>(
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

            context.insert(SDAccount(
                id: UUID(), name: "Cash", type: AccountType.cash.rawValue,
                icon: "banknote", color: "#2ECC71", sortOrder: 0,
                isArchived: false, createdAt: Date()
            ))

            try context.save()
        } catch {
            print("Failed to seed default data: \(error)")
        }
    }
}
