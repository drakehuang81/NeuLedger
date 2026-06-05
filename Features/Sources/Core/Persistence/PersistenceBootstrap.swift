import Foundation
import SwiftData
import Dependencies
import Domain

/// A TCA dependency that provides access to the SwiftData `ModelContainer`.
///
/// Use `PersistenceBootstrap` to obtain the shared `ModelContainer` from which
/// live client implementations derive their `ModelContext` instances.
///
/// ```swift
/// @Dependency(\.persistenceBootstrap) var persistenceBootstrap
/// let container = persistenceBootstrap.modelContainer()
/// ```
public struct PersistenceBootstrap: Sendable {
    /// Returns the configured `ModelContainer` for the application.
    public var modelContainer: @Sendable () -> ModelContainer

    public init(modelContainer: @escaping @Sendable () -> ModelContainer) {
        self.modelContainer = modelContainer
    }
}

// MARK: - Live Value

extension PersistenceBootstrap: DependencyKey {
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

    public static let localConfiguration = ModelConfiguration(
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

    public static let liveValue = PersistenceBootstrap(
        modelContainer: { PersistenceBootstrap.container }
    )

    /// In-memory `ModelContainer` shared by `PersistenceBootstrap.testValue` and
    /// `\.modelContainer`'s testValue. Created once per process so tests
    /// running in the same target share seeded default data.
    public static let testContainer: ModelContainer = {
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

    /// An in-memory `PersistenceBootstrap` suitable for unit tests.
    public static let testValue = PersistenceBootstrap(
        modelContainer: { PersistenceBootstrap.testContainer }
    )
}

// Analytics aggregation moved to `TransactionAnalyticsKernel` (Phase 5.5)
// so `AnalyticsUseCase+Live` owns the read-side semantic boundary and
// `PersistenceBootstrap` returns to a focused role: container lifecycle +
// seed data.

// MARK: - DependencyValues Registration

public extension DependencyValues {
    /// The persistence bootstrap providing access to the SwiftData `ModelContainer`.
    var persistenceBootstrap: PersistenceBootstrap {
        get { self[PersistenceBootstrap.self] }
        set { self[PersistenceBootstrap.self] = newValue }
    }
}

// MARK: - Seed Data

/// A default category bundled with the app. The `id` is fixed (not random)
/// so the same default category seeded on two devices — or after a
/// delete-and-reinstall — produces SwiftData rows that share a UUID, which
/// lets `seedIfNeeded` skip rows already present from a prior CloudKit sync.
struct SeedCategory {
    let id: UUID
    let name: String
    let icon: String
    let color: String
}

extension SeedCategory {
    private static func stableID(_ suffix: String) -> UUID {
        UUID(uuidString: "9E0FED11-CCCC-0000-0000-0000000000\(suffix)")!
    }

    static var food: SeedCategory {
        SeedCategory(id: stableID("01"), name: "Food", icon: "fork.knife", color: "#FF6B6B")
    }

    static var transport: SeedCategory {
        SeedCategory(id: stableID("02"), name: "Transport", icon: "car.fill", color: "#4ECDC4")
    }

    static var entertainment: SeedCategory {
        SeedCategory(id: stableID("03"), name: "Entertainment", icon: "gamecontroller.fill", color: "#45B7D1")
    }

    static var shopping: SeedCategory {
        SeedCategory(id: stableID("04"), name: "Shopping", icon: "bag.fill", color: "#96CEB4")
    }

    static var housing: SeedCategory {
        SeedCategory(id: stableID("05"), name: "Housing", icon: "house.fill", color: "#FFEAA7")
    }

    static var utilities: SeedCategory {
        SeedCategory(id: stableID("06"), name: "Utilities", icon: "bolt.fill", color: "#DDA0DD")
    }

    static var health: SeedCategory {
        SeedCategory(id: stableID("07"), name: "Health", icon: "heart.fill", color: "#FF6B9D")
    }

    static var education: SeedCategory {
        SeedCategory(id: stableID("08"), name: "Education", icon: "book.fill", color: "#C9B1FF")
    }

    static var otherExpense: SeedCategory {
        SeedCategory(id: stableID("09"), name: "Other Expense", icon: "ellipsis.circle.fill", color: "#95A5A6")
    }

    static var salary: SeedCategory {
        SeedCategory(id: stableID("0A"), name: "Salary", icon: "banknote.fill", color: "#2ECC71")
    }

    static var freelance: SeedCategory {
        SeedCategory(id: stableID("0B"), name: "Freelance", icon: "laptopcomputer", color: "#3498DB")
    }

    static var investment: SeedCategory {
        SeedCategory(id: stableID("0C"), name: "Investment", icon: "chart.line.uptrend.xyaxis", color: "#F39C12")
    }

    static var gift: SeedCategory {
        SeedCategory(id: stableID("0D"), name: "Gift", icon: "gift.fill", color: "#E74C3C")
    }

    static var otherIncome: SeedCategory {
        SeedCategory(id: stableID("0E"), name: "Other Income", icon: "ellipsis.circle.fill", color: "#1ABC9C")
    }
    static var defaultExpenseCategories: [SeedCategory] {
        [.food, .transport, .entertainment, .shopping, .housing, .utilities, .health, .education, .otherExpense]
    }
    static var defaultIncomeCategories: [SeedCategory] {
        [.salary, .freelance, .investment, .gift, .otherIncome]
    }
}



// MARK: - Seeding

private extension PersistenceBootstrap {
    static func seedIfNeeded(in context: ModelContext) {
        do {
            try insertMissingDefaults(SeedCategory.defaultExpenseCategories,
                                      type: .expense, in: context)
            try insertMissingDefaults(SeedCategory.defaultIncomeCategories,
                                      type: .income, in: context)

            if context.hasChanges {
                try context.save()
            }
        } catch {
            print("Failed to seed default data: \(error)")
        }
    }

    static func insertMissingDefaults(_ seeds: [SeedCategory],
                                      type: TransactionType,
                                      in context: ModelContext) throws {
        for (index, seed) in seeds.enumerated() {
            let seedID = seed.id
            var descriptor = FetchDescriptor<SDCategory>(
                predicate: #Predicate { $0.id == seedID }
            )
            descriptor.fetchLimit = 1
            if try context.fetch(descriptor).first != nil { continue }

            context.insert(SDCategory(
                id: seed.id, name: seed.name, icon: seed.icon, color: seed.color,
                type: type.rawValue, sortOrder: index, isDefault: true
            ))
        }
    }
}
