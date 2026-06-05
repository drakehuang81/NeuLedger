import Foundation
import Testing
import Dependencies
@testable import Domain

@Suite("CarrierClient Domain Tests")
struct CarrierClientTests {

    @Test("CarrierClient testValue is accessible via DependencyValues")
    func testDependencyKey() {
        @Dependency(\.carrierClient) var client
        #expect(true, "CarrierClient injected successfully")
    }

    @Test("CarrierClient listAll mock override")
    func testListAllMock() async throws {
        let expected = [Carrier(name: "手機載具", type: .phoneBarcodeCarrier, barcode: "/ABC1234")]
        try await withDependencies {
            $0.carrierClient.listAll = { expected }
        } operation: {
            @Dependency(\.carrierClient) var client
            let result = try await client.listAll()
            #expect(result == expected)
        }
    }

    @Test("CarrierClient create mock override")
    func testCreateMock() async throws {
        try await withDependencies {
            $0.carrierClient.create = { _ in }
        } operation: {
            @Dependency(\.carrierClient) var client
            let carrier = Carrier(name: "手機載具", type: .phoneBarcodeCarrier, barcode: "/ABC1234")
            try await client.create(carrier)
        }
    }

    @Test("CarrierClient update mock override")
    func testUpdateMock() async throws {
        try await withDependencies {
            $0.carrierClient.update = { _ in }
        } operation: {
            @Dependency(\.carrierClient) var client
            let carrier = Carrier(name: "手機載具", type: .phoneBarcodeCarrier, barcode: "/ABC1234")
            try await client.update(carrier)
        }
    }

    @Test("CarrierClient delete mock override")
    func testDeleteMock() async throws {
        let id = UUID()
        try await withDependencies {
            $0.carrierClient.delete = { _ in }
        } operation: {
            @Dependency(\.carrierClient) var client
            try await client.delete(id)
        }
    }

    @Test("CarrierClient setActiveForWidget mock override")
    func testSetActiveForWidgetMock() async {
        await withDependencies {
            $0.carrierClient.setActiveForWidget = { _ in }
        } operation: {
            @Dependency(\.carrierClient) var client
            await client.setActiveForWidget(UUID())
        }
    }

    @Test("CarrierClient activeForWidget mock override")
    func testActiveForWidgetMock() async {
        let id = UUID()
        withDependencies {
            $0.carrierClient.activeForWidget = { id }
        } operation: {
            @Dependency(\.carrierClient) var client
            let result = client.activeForWidget()
            #expect(result == id)
        }
    }
}
