// Features/Tests/DomainTests/Clients/CarrierClientTests.swift
import Foundation
import Testing
import Dependencies
@testable import Domain

@Suite("CarrierClient Tests")
struct CarrierClientTests {

    @Test("CarrierClient dependency key injection")
    func testDependencyKey() {
        @Dependency(\.carrierClient) var client
        #expect(true, "CarrierClient injected successfully")
    }

    @Test("CarrierClient fetchAll mock override")
    func testFetchAllMock() async throws {
        let expected = [Carrier(name: "手機載具", type: .phoneBarcodeCarrier, barcode: "/ABC1234")]
        try await withDependencies {
            $0.carrierClient.fetchAll = { expected }
        } operation: {
            @Dependency(\.carrierClient) var client
            let result = try await client.fetchAll()
            #expect(result == expected)
        }
    }

    @Test("CarrierClient add mock override")
    func testAddMock() async throws {
        try await withDependencies {
            $0.carrierClient.add = { _ in }
        } operation: {
            @Dependency(\.carrierClient) var client
            let carrier = Carrier(name: "手機載具", type: .phoneBarcodeCarrier, barcode: "/ABC1234")
            try await client.add(carrier)
        }
    }
}
