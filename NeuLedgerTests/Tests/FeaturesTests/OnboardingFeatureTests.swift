import Testing
import ComposableArchitecture
import Domain
import Foundation
@testable import Features

@Suite("OnboardingFeature Tests")
struct OnboardingFeatureTests {

    // ── Step navigation ──────────────────────────────────────────────

    @Test("nextButtonTapped: welcome -> accountSelection")
    func testNextFromWelcome() async {
        let store = await TestStore(initialState: OnboardingFeature.State()) {
            OnboardingFeature()
        }
        await store.send(.nextButtonTapped) {
            $0.currentStep = .accountSelection
        }
    }

    @Test("nextButtonTapped: accountSelection -> ready")
    func testNextFromAccountSelection() async {
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

    @Test("sheet delegate.submitted appends draft and dismisses sheet")
    func testSheetSubmit() async {
        let draftId = UUID(uuidString: "00000000-0000-0000-0000-000000000010")!
        let draft = CustomAccountDraft(id: draftId, name: "玉山銀行", type: .bank, color: "#0A84FF")

        let store = await TestStore(
            initialState: OnboardingFeature.State(
                customAccountSheet: CustomAccountFormFeature.State(name: "玉山銀行", type: .bank, color: "#0A84FF")
            )
        ) {
            OnboardingFeature()
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

    // ── Finish flow (ready → done → setup accounts → delegate) ───────

    @Test("nextButtonTapped on ready triggers finishOnboarding and writes accounts")
    func testFinishWritesAccounts() async {
        let captured = LockIsolated<[Account]>([])
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
            $0.accountClient.setupAccounts = { accounts in
                captured.withValue { $0 = accounts }
            }
            $0.platformClient.markOnboardingComplete = {}
            $0.continuousClock = clock
        }

        await store.send(.nextButtonTapped) {
            $0.currentStep = .done
        }
        await store.receive(\.finishOnboarding)
        await clock.advance(by: .milliseconds(1600))
        await store.receive(\.delegate.onboardingCompleted)

        let names = captured.value.map(\.name)
        let types = Set(captured.value.map(\.type))
        #expect(captured.value.count == 3)
        #expect(types == [.cash, .creditCard, .bank])
        #expect(names.contains("玉山銀行"))
    }

    @Test("finishOnboarding directly writes accounts and completes")
    func testFinishOnboardingDirect() async {
        let captured = LockIsolated<[Account]>([])
        let clock = TestClock()

        let store = await TestStore(
            initialState: OnboardingFeature.State(
                currentStep: .done,
                selectedTypes: [.cash]
            )
        ) {
            OnboardingFeature()
        } withDependencies: {
            $0.accountClient.setupAccounts = { accounts in
                captured.withValue { $0 = accounts }
            }
            $0.platformClient.markOnboardingComplete = {}
            $0.continuousClock = clock
        }

        await store.send(.finishOnboarding)
        await clock.advance(by: .milliseconds(1600))
        await store.receive(\.delegate.onboardingCompleted)

        #expect(captured.value.count == 1)
        #expect(captured.value.first?.type == .cash)
    }

    // ── Finish effect ordering (setupAccounts → markOnboardingComplete → delegate) ──

    @Test("finishOnboarding marks onboarding complete after writing accounts and before completing")
    func testFinishEffectOrdering() async {
        // Records the sequence of side effects in the order they fire.
        let events = LockIsolated<[String]>([])
        let clock = TestClock()

        let store = await TestStore(
            initialState: OnboardingFeature.State(
                currentStep: .done,
                selectedTypes: [.cash]
            )
        ) {
            OnboardingFeature()
        } withDependencies: {
            $0.accountClient.setupAccounts = { _ in
                events.withValue { $0.append("setupAccounts") }
            }
            $0.platformClient.markOnboardingComplete = {
                events.withValue { $0.append("markOnboardingComplete") }
            }
            $0.continuousClock = clock
        }

        await store.send(.finishOnboarding)
        await clock.advance(by: .milliseconds(1600))
        await store.receive(\.delegate.onboardingCompleted)

        // setupAccounts runs first (awaited), then markOnboardingComplete runs
        // synchronously right after, and only then the 1600ms sleep + delegate.
        // The captured order proves both side effects fired exactly once, in
        // that order, before completion.
        #expect(events.value == ["setupAccounts", "markOnboardingComplete"])
    }
}
