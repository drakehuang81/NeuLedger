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
    /// previously enabled. Replaced at runtime by CloudSyncUseCase during the migration flow.
    nonisolated(unsafe) public static var container: ModelContainer = {
        do {
            // Read raw UserDefaults directly here (rather than via UserSettingsAdapter)
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

// Analytics aggregation moved to `TransactionAnalyticsKernel` (Phase 5.5)
// so `AnalyticsUseCase+Live` owns the read-side semantic boundary and
// `DatabaseClient` returns to a focused role: container lifecycle +
// seed data.

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
