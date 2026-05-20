import Testing
import ComposableArchitecture
import Domain
import Foundation
@testable import Features

@Suite("OnboardingFeature Tests (Redesign)")
struct OnboardingFeatureTests {

    // ── Step navigation ──────────────────────────────────────────────

    @Test("startButtonTapped: welcome -> accountSelection")
    func testStart() async {
        let store = await TestStore(initialState: OnboardingFeature.State()) {
            OnboardingFeature()
        }
        await store.send(.startButtonTapped) {
            $0.currentStep = .accountSelection
        }
    }

    @Test("nextButtonTapped: accountSelection -> ready")
    func testNext() async {
        let store = await TestStore(
            initialState: OnboardingFeature.State(currentStep: .accountSelection)
        ) {
            OnboardingFeature()
        }
        await store.send(.nextButtonTapped) {
            $0.currentStep = .ready
        }
    }

    // ── Type toggle ──────────────────────────────────────────────────

    @Test("typeToggled adds type when not selected")
    func testToggleAdd() async {
        let store = await TestStore(
            initialState: OnboardingFeature.State(selectedTypes: [.cash])
        ) {
            OnboardingFeature()
        }
        await store.send(.typeToggled(.bank)) {
            $0.selectedTypes = [.cash, .bank]
        }
    }

    @Test("typeToggled removes type when already selected")
    func testToggleRemove() async {
        let store = await TestStore(
            initialState: OnboardingFeature.State(selectedTypes: [.cash, .bank])
        ) {
            OnboardingFeature()
        }
        await store.send(.typeToggled(.bank)) {
            $0.selectedTypes = [.cash]
        }
    }

    // ── Custom account sheet ─────────────────────────────────────────

    @Test("addCustomAccountTapped opens the sheet")
    func testOpenSheet() async {
        let store = await TestStore(initialState: OnboardingFeature.State()) {
            OnboardingFeature()
        } withDependencies: {
            $0.uuid = .incrementing
        }
        await store.send(.addCustomAccountTapped) {
            $0.customAccountSheet = CustomAccountFormFeature.State()
        }
    }

    @Test("sheet delegate.submitted appends to customAccounts and dismisses sheet")
    func testSheetSubmit() async {
        let draftId = UUID(uuidString: "00000000-0000-0000-0000-000000000010")!
        let draft = CustomAccountDraft(id: draftId, name: "玉山銀行", type: .bank, color: "#0A84FF")

        let store = await TestStore(
            initialState: OnboardingFeature.State(
                customAccountSheet: CustomAccountFormFeature.State(name: "玉山銀行", type: .bank, color: "#0A84FF")
            )
        ) {
            OnboardingFeature()
        } withDependencies: {
            $0.uuid = .constant(draftId)
        }

        await store.send(.customAccountSheet(.presented(.delegate(.submitted(draft))))) {
            $0.customAccounts = [draft]
            $0.customAccountSheet = nil
        }
    }

    @Test("sheet delegate.dismissed clears the sheet")
    func testSheetDismiss() async {
        let store = await TestStore(
            initialState: OnboardingFeature.State(
                customAccountSheet: CustomAccountFormFeature.State()
            )
        ) {
            OnboardingFeature()
        }
        await store.send(.customAccountSheet(.presented(.delegate(.dismissed)))) {
            $0.customAccountSheet = nil
        }
    }

    @Test("customAccountDeleted removes by id")
    func testDeleteCustom() async {
        let id1 = UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!
        let id2 = UUID(uuidString: "00000000-0000-0000-0000-0000000000A2")!
        let d1  = CustomAccountDraft(id: id1, name: "玉山", type: .bank, color: "#0A84FF")
        let d2  = CustomAccountDraft(id: id2, name: "悠遊", type: .eWallet, color: "#5E5CE6")

        let store = await TestStore(
            initialState: OnboardingFeature.State(customAccounts: [d1, d2])
        ) {
            OnboardingFeature()
        }
        await store.send(.customAccountDeleted(id1)) {
            $0.customAccounts = [d2]
        }
    }

    // ── Finish & Skip (write accounts) ───────────────────────────────

    @Test("finishButtonTapped writes selected types + customs, transitions to done")
    func testFinishWritesAccounts() async {
        let added = LockIsolated<[Account]>([])
        let setBoolCalled = LockIsolated(false)
        let id1 = UUID(uuidString: "00000000-0000-0000-0000-0000000000B1")!
        let custom = CustomAccountDraft(id: id1, name: "玉山銀行", type: .bank, color: "#0A84FF")

        let clock = TestClock()

        let store = await TestStore(
            initialState: OnboardingFeature.State(
                currentStep: .ready,
                selectedTypes: [.cash, .creditCard],
                customAccounts: [custom]
            )
        ) {
            OnboardingFeature()
        } withDependencies: {
            $0.userSettingsAdapter.setBool = { _, _ in setBoolCalled.setValue(true) }
            $0.accountClient.add = { acc in
                added.withValue { $0.append(acc) }
            }
            $0.continuousClock = clock
        }

        await store.send(.finishButtonTapped) {
            $0.isCreatingAccounts = true
        }
        await store.receive(\.accountsCreated) {
            $0.currentStep = .done
        }
        await clock.advance(by: .milliseconds(1600))
        await store.receive(\.doneAnimationFinished)
        await store.receive(\.delegate.onboardingCompleted)

        let names = added.value.map(\.name).sorted()
        let types = Set(added.value.map(\.type))
        #expect(setBoolCalled.value == true)
        #expect(added.value.count == 3)
        #expect(types == [.cash, .creditCard, .bank])
        #expect(names.contains("玉山銀行"))
    }

    @Test("skipButtonTapped writes default cash account and transitions to done")
    func testSkip() async {
        let added = LockIsolated<Account?>(nil)
        let setBoolCalled = LockIsolated(false)
        let clock = TestClock()

        let store = await TestStore(
            initialState: OnboardingFeature.State(currentStep: .welcome)
        ) {
            OnboardingFeature()
        } withDependencies: {
            $0.userSettingsAdapter.setBool = { _, _ in setBoolCalled.setValue(true) }
            $0.accountClient.add = { acc in added.setValue(acc) }
            $0.continuousClock = clock
        }

        await store.send(.skipButtonTapped) {
            $0.isCreatingAccounts = true
        }
        await store.receive(\.accountsCreated) {
            $0.currentStep = .done
        }
        await clock.advance(by: .milliseconds(1600))
        await store.receive(\.doneAnimationFinished)
        await store.receive(\.delegate.onboardingCompleted)

        let acc = added.value
        #expect(acc?.type == .cash)
        #expect(acc?.icon == "banknote")
        #expect(setBoolCalled.value == true)
    }
}
