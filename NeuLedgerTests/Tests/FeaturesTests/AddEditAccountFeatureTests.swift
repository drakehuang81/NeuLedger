import Testing
import Foundation
import ComposableArchitecture
@testable import Features
import Domain

@Suite("AddEditAccountFeature Tests")
struct AddEditAccountFeatureTests {

    // MARK: - State init defaults (audit A1)

    @Test("add mode defaults follow AccountType.cash SSOT (defaultIcon/defaultColor)")
    func testAddModeDefaultsFollowAccountTypeSSOT() async {
        let state = AddEditAccountFeature.State(mode: .add)
        #expect(state.type == .cash)
        #expect(state.icon == state.type.defaultIcon)
        #expect(state.colorHex == state.type.defaultColor)
    }

    @Test("edit mode init copies the account's own icon and color")
    func testEditModeCopiesAccountValues() async {
        let account = Account(
            id: "acc-1", name: "玉山銀行", type: .bank,
            icon: "building.columns", color: "#0A84FF",
            sortOrder: 0, isArchived: false, createdAt: Date()
        )
        let state = AddEditAccountFeature.State(mode: .edit(account))
        #expect(state.icon == "building.columns")
        #expect(state.colorHex == "#0A84FF")
    }
}
