import Foundation
import SwiftData
import Dependencies

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
            DefaultDataSeeder.seed(in: context)
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
            DefaultDataSeeder.seed(in: context)
        } catch {
            fatalError("Failed to create test ModelContainer: \(error)")
        }
        return DatabaseClient(
            modelContainer: { container }
        )
    }()
}

// MARK: - DependencyValues Registration

public extension DependencyValues {
    /// The database client providing access to the SwiftData `ModelContainer`.
    var databaseClient: DatabaseClient {
        get { self[DatabaseClient.self] }
        set { self[DatabaseClient.self] = newValue }
    }
}
