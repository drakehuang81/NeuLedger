import Testing
import Foundation
import SwiftData
import Dependencies
import Domain
@testable import Core

@Suite("CarrierClient Live Tests")
struct CarrierClientLiveTests {

    /// Fresh in-memory container holding only the `SDCarrier` schema.
    private func freshCarrierContainer() throws -> ModelContainer {
        let schema = Schema([SDCarrier.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    /// An in-memory `UserSettingsAdapter` backed by an actor-isolated dictionary,
    /// so `setActiveForWidget` / `activeForWidget` round-trips can be verified.
    private final class SettingsBox: @unchecked Sendable {
        private let lock = NSLock()
        private var storage: [String: String] = [:]
        func get(_ key: String) -> String {
            lock.lock(); defer { lock.unlock() }
            return storage[key] ?? ""
        }
        func set(_ value: String, _ key: String) {
            lock.lock(); defer { lock.unlock() }
            storage[key] = value
        }
    }

    private func inMemorySettings(_ box: SettingsBox) -> UserSettingsAdapter {
        var adapter = UserSettingsAdapter.testValue
        adapter.string = { key in box.get(key.rawValue) }
        adapter.setString = { value, key in box.set(value, key.rawValue) }
        return adapter
    }

    /// A spy `WidgetSyncAdapter` recording how many times a carrier-widget reload
    /// (`syncAllCarriers`) was triggered.
    private final class WidgetSpy: @unchecked Sendable {
        private let lock = NSLock()
        private(set) var syncAllCount = 0
        func recordSyncAll() {
            lock.lock(); defer { lock.unlock() }
            syncAllCount += 1
        }
        var count: Int {
            lock.lock(); defer { lock.unlock() }
            return syncAllCount
        }
    }

    private func spyWidgetAdapter(_ spy: WidgetSpy) -> WidgetSyncAdapter {
        var adapter = WidgetSyncAdapter.testValue
        adapter.syncCarrier = { _, _, _ in }
        adapter.clearCarrier = {}
        adapter.syncAllCarriers = { _ in spy.recordSyncAll() }
        return adapter
    }

    private func sample(_ name: String = "手機載具") -> Carrier {
        Carrier(name: name, type: .phoneBarcodeCarrier, barcode: "/ABC1234")
    }

    // MARK: - CRUD (migrated from CarrierRepositoryTests)

    @Test("create then listAll returns the inserted carrier")
    func testCreateThenList() async throws {
        let container = try freshCarrierContainer()
        let spy = WidgetSpy()
        try await withDependencies {
            $0.modelContainer = container
            $0.widgetSyncAdapter = spyWidgetAdapter(spy)
            $0.userSettingsAdapter = inMemorySettings(SettingsBox())
        } operation: {
            let client = CarrierClient.liveValue
            let carrier = sample()
            try await client.create(carrier)
            let all = try await client.listAll()
            #expect(all.count == 1)
            #expect(all.first?.id == carrier.id)
            #expect(all.first?.name == "手機載具")
        }
    }

    @Test("update persists changes")
    func testUpdate() async throws {
        let container = try freshCarrierContainer()
        let spy = WidgetSpy()
        try await withDependencies {
            $0.modelContainer = container
            $0.widgetSyncAdapter = spyWidgetAdapter(spy)
            $0.userSettingsAdapter = inMemorySettings(SettingsBox())
        } operation: {
            let client = CarrierClient.liveValue
            let carrier = sample("舊名")
            try await client.create(carrier)

            var edited = carrier
            edited.name = "新名"
            try await client.update(edited)

            let all = try await client.listAll()
            #expect(all.count == 1)
            #expect(all.first?.name == "新名")
        }
    }

    @Test("delete removes the carrier")
    func testDelete() async throws {
        let container = try freshCarrierContainer()
        let spy = WidgetSpy()
        try await withDependencies {
            $0.modelContainer = container
            $0.widgetSyncAdapter = spyWidgetAdapter(spy)
            $0.userSettingsAdapter = inMemorySettings(SettingsBox())
        } operation: {
            let client = CarrierClient.liveValue
            let carrier = sample()
            try await client.create(carrier)
            try await client.delete(carrier.id)
            let all = try await client.listAll()
            #expect(all.isEmpty)
        }
    }

    // MARK: - New: widget reload post-condition

    @Test("create triggers a carrier widget reload")
    func testCreateTriggersWidgetReload() async throws {
        let container = try freshCarrierContainer()
        let spy = WidgetSpy()
        try await withDependencies {
            $0.modelContainer = container
            $0.widgetSyncAdapter = spyWidgetAdapter(spy)
            $0.userSettingsAdapter = inMemorySettings(SettingsBox())
        } operation: {
            let client = CarrierClient.liveValue
            try await client.create(sample())
            #expect(spy.count == 1)
        }
    }

    @Test("update triggers a carrier widget reload")
    func testUpdateTriggersWidgetReload() async throws {
        let container = try freshCarrierContainer()
        let spy = WidgetSpy()
        try await withDependencies {
            $0.modelContainer = container
            $0.widgetSyncAdapter = spyWidgetAdapter(spy)
            $0.userSettingsAdapter = inMemorySettings(SettingsBox())
        } operation: {
            let client = CarrierClient.liveValue
            let carrier = sample()
            try await client.create(carrier)
            let before = spy.count
            try await client.update(carrier)
            #expect(spy.count == before + 1)
        }
    }

    @Test("delete triggers a carrier widget reload")
    func testDeleteTriggersWidgetReload() async throws {
        let container = try freshCarrierContainer()
        let spy = WidgetSpy()
        try await withDependencies {
            $0.modelContainer = container
            $0.widgetSyncAdapter = spyWidgetAdapter(spy)
            $0.userSettingsAdapter = inMemorySettings(SettingsBox())
        } operation: {
            let client = CarrierClient.liveValue
            let carrier = sample()
            try await client.create(carrier)
            let before = spy.count
            try await client.delete(carrier.id)
            #expect(spy.count == before + 1)
        }
    }

    @Test("setActiveForWidget triggers a carrier widget reload")
    func testSetActiveTriggersWidgetReload() async throws {
        let container = try freshCarrierContainer()
        let spy = WidgetSpy()
        await withDependencies {
            $0.modelContainer = container
            $0.widgetSyncAdapter = spyWidgetAdapter(spy)
            $0.userSettingsAdapter = inMemorySettings(SettingsBox())
        } operation: {
            let client = CarrierClient.liveValue
            await client.setActiveForWidget(UUID())
            #expect(spy.count == 1)
        }
    }

    // MARK: - New: active widget carrier round-trip

    @Test("setActiveForWidget then activeForWidget reads back the same id")
    func testActiveForWidgetRoundTrip() async throws {
        let container = try freshCarrierContainer()
        let spy = WidgetSpy()
        let box = SettingsBox()
        await withDependencies {
            $0.modelContainer = container
            $0.widgetSyncAdapter = spyWidgetAdapter(spy)
            $0.userSettingsAdapter = inMemorySettings(box)
        } operation: {
            let client = CarrierClient.liveValue
            let id = UUID()
            await client.setActiveForWidget(id)
            let readBack = client.activeForWidget()
            #expect(readBack == id)
        }
    }

    @Test("activeForWidget returns nil when nothing is set")
    func testActiveForWidgetNilWhenUnset() async throws {
        let container = try freshCarrierContainer()
        let spy = WidgetSpy()
        await withDependencies {
            $0.modelContainer = container
            $0.widgetSyncAdapter = spyWidgetAdapter(spy)
            $0.userSettingsAdapter = inMemorySettings(SettingsBox())
        } operation: {
            let client = CarrierClient.liveValue
            #expect(client.activeForWidget() == nil)
        }
    }
}
