import Testing
import Foundation
import ComposableArchitecture
import Domain
@testable import Features

@Suite("CustomAccountFormFeature Tests")
struct CustomAccountFormFeatureTests {

    @Test("canSubmit is false when name is empty / whitespace")
    func testCanSubmit() {
        var s = CustomAccountFormFeature.State()
        #expect(s.canSubmit == false)
        s.name = "   "
        #expect(s.canSubmit == false)
        s.name = "玉山"
        #expect(s.canSubmit == true)
    }

    @Test("binding updates name / type / color")
    func testBinding() async {
        let store = await TestStore(initialState: CustomAccountFormFeature.State()) {
            CustomAccountFormFeature()
        }
        await store.send(\.binding.name, "悠遊卡") { $0.name = "悠遊卡" }
        await store.send(\.binding.type, .eWallet) { $0.type = .eWallet }
        await store.send(\.binding.color, "#5E5CE6") { $0.color = "#5E5CE6" }
    }

    @Test("submitTapped emits delegate.submitted with draft (uses uuid dependency)")
    func testSubmitEmitsDelegate() async {
        let fixedUUID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let store = await TestStore(
            initialState: CustomAccountFormFeature.State(name: "玉山銀行", type: .bank, color: "#0A84FF")
        ) {
            CustomAccountFormFeature()
        } withDependencies: {
            $0.uuid = .constant(fixedUUID)
        }

        await store.send(.submitTapped)
        await store.receive(\.delegate.submitted)
    }

    @Test("submitTapped delegate carries the expected draft fields")
    func testSubmitDraftPayload() async {
        let captured = LockIsolated<CustomAccountDraft?>(nil)
        let fixedUUID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let store = await TestStore(
            initialState: CustomAccountFormFeature.State(name: "  Visa  ", type: .creditCard, color: "#FF2D55")
        ) {
            CustomAccountFormFeature()
        } withDependencies: {
            $0.uuid = .constant(fixedUUID)
        }

        await store.send(.submitTapped)
        await store.receive { action in
            if case let .delegate(.submitted(draft)) = action {
                captured.setValue(draft)
                return true
            }
            return false
        }

        let d = captured.value
        #expect(d?.id == fixedUUID)
        #expect(d?.name == "Visa")          // trimmed
        #expect(d?.type == .creditCard)
        #expect(d?.color == "#FF2D55")
    }

    @Test("submitTapped is a no-op when canSubmit is false")
    func testSubmitNoOpWhenInvalid() async {
        let store = await TestStore(
            initialState: CustomAccountFormFeature.State(name: "  ", type: .bank, color: "#0A84FF")
        ) {
            CustomAccountFormFeature()
        }
        await store.send(.submitTapped)
        // No effects fire; TestStore strict mode catches missing handler if delegate fires.
    }
}
