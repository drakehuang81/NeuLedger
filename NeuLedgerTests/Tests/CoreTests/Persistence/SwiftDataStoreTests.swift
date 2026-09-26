import Testing
import Foundation
import SwiftData
import Dependencies
import Domain
@testable import Core

@Suite("SwiftDataStore")
struct SwiftDataStoreTests {

    /// Fresh in-memory container holding only the schema needed for these tests.
    /// Avoids the default-data seeding inside `PersistenceBootstrap.testContainer`,
    /// which would put 14 seed categories into `fetchAll` results and break
    /// equality assertions.
    private func freshAccountContainer() throws -> ModelContainer {
        let schema = Schema([SDAccount.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    @Test("add then fetch returns the inserted entity")
    func testAddThenFetch() async throws {
        let container = try freshAccountContainer()
        try await withDependencies {
            $0.modelContainer = container
        } operation: {
            let store = AccountStore()
            let acc = Account(name: "Cash", type: .cash, icon: "", color: "#000000")
            try await store.add(acc)
            let fetched = try await store.fetch(id: acc.id)
            #expect(fetched?.name == "Cash")
            #expect(fetched?.id == acc.id)
        }
    }

    @Test("update persists applyChanges via the mapper")
    func testUpdatePersistsChanges() async throws {
        let container = try freshAccountContainer()
        try await withDependencies {
            $0.modelContainer = container
        } operation: {
            let store = AccountStore()
            let acc = Account(name: "Old", type: .cash, icon: "", color: "#000000")
            try await store.add(acc)

            var edited = acc
            edited.name = "New"
            edited.type = .bank
            try await store.update(edited)

            let fetched = try await store.fetch(id: acc.id)
            #expect(fetched?.name == "New")
            #expect(fetched?.type == .bank)
        }
    }

    @Test("delete removes the entity by id")
    func testDeleteRemovesEntity() async throws {
        let container = try freshAccountContainer()
        try await withDependencies {
            $0.modelContainer = container
        } operation: {
            let store = AccountStore()
            let acc = Account(name: "X", type: .cash, icon: "", color: "#000000")
            try await store.add(acc)
            try await store.delete(id: acc.id)
            let fetched = try await store.fetch(id: acc.id)
            #expect(fetched == nil)
        }
    }

    @Test("fetchAll returns Domain values respecting the SortDescriptor")
    func testFetchAllSorted() async throws {
        let container = try freshAccountContainer()
        try await withDependencies {
            $0.modelContainer = container
        } operation: {
            let store = AccountStore()
            try await store.add(Account(name: "B", type: .bank, icon: "", color: "#000"))
            try await store.add(Account(name: "A", type: .cash, icon: "", color: "#000"))
            let all = try await store.fetchAll(sortBy: [SortDescriptor(\.name)])
            #expect(all.map(\.name) == ["A", "B"])
        }
    }

    @Test("update throws CoreError.notFound when the entity is missing")
    func testUpdateThrowsNotFound() async throws {
        let container = try freshAccountContainer()
        await withDependencies {
            $0.modelContainer = container
        } operation: { @Sendable in
            let store = AccountStore()
            let phantom = Account(name: "phantom", type: .cash, icon: "", color: "#000")
            await #expect(throws: CoreError.self) {
                try await store.update(phantom)
            }
        }
    }

    @Test("delete throws CoreError.notFound when the entity is missing")
    func testDeleteThrowsNotFound() async throws {
        let container = try freshAccountContainer()
        await withDependencies {
            $0.modelContainer = container
        } operation: { @Sendable in
            let store = AccountStore()
            await #expect(throws: CoreError.self) {
                try await store.delete(id: UUID().uuidString)
            }
        }
    }

    // MARK: - Container indirection (spec A3)
    //
    // `\.modelContainer` used to be a plain computed property, but
    // swift-dependencies caches the *resolved value* per key type, so the
    // first resolution pinned the `ModelContainer` instance for the rest of
    // the process — switching iCloud sync or wiping data only replaced
    // `PersistenceBootstrap.container`, and already-resolved stores never
    // saw the new container until the next cold launch. `SwiftDataStore`
    // now depends on a `ModelContainerBox` instead: the box itself stays
    // cached, but swapping its `container` property is visible immediately
    // to every store that reads through it.
    @Test("a store follows the box when its content is swapped mid-dependency")
    func testStoreFollowsTheBox() async throws {
        let schema = Schema([SDAccount.self])
        let first = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        let second = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        let box = ModelContainerBox(first)

        try await withDependencies {
            $0.modelContainerBox = box
        } operation: {
            let store = AccountStore()
            try await store.add(Account(name: "Cash", type: .cash, icon: "banknote", color: "#FFFFFF"))
            #expect(try await store.fetchAll().count == 1)

            // 換掉 box 的內容（等同 switchToCloudContainer / wipeAllSyncData 做的事）。
            box.container = second
            #expect(
                try await store.fetchAll().isEmpty,
                "換過容器之後，store 必須讀寫新的容器"
            )
        }
    }
}
