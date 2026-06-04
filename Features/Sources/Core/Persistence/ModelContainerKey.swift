import Foundation
import SwiftData
import Dependencies

public extension DependencyValues {
    /// The shared SwiftData `ModelContainer`.
    ///
    /// **Access scope:** only `SwiftDataStore` may depend on this. Repositories
    /// and above must route through `SwiftDataStore<Domain, SD>` instead of
    /// touching the container directly. See `docs/architecture.md` §4.2.
    var modelContainer: ModelContainer {
        get { self[ModelContainerKey.self] }
        set { self[ModelContainerKey.self] = newValue }
    }
}

private enum ModelContainerKey: DependencyKey {
    static var liveValue: ModelContainer { PersistenceBootstrap.container }
    static var testValue: ModelContainer { PersistenceBootstrap.testContainer }
}
