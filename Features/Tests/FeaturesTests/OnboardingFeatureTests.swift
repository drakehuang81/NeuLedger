import Testing
import ComposableArchitecture
import Domain
@testable import Features

@Suite("OnboardingFeature Tests")
struct OnboardingFeatureTests {

    // MARK: - Step Navigation

    @Test("startButtonTapped transitions from welcome to accountSetup")
    func testStartButtonTapped() async throws {
        let store = await TestStore(
            initialState: OnboardingFeature.State()
        ) {
            OnboardingFeature()
        }

        await store.send(.startButtonTapped) {
            $0.currentStep = .accountSetup
        }
    }

    @Test("nextButtonTapped transitions from accountSetup to ready")
    func testNextButtonTapped() async throws {
        let store = await TestStore(
            initialState: OnboardingFeature.State(currentStep: .accountSetup)
        ) {
            OnboardingFeature()
        }

        await store.send(.nextButtonTapped) {
            $0.currentStep = .ready
        }
    }

    // MARK: - Finish & UserSettingsClient

    @Test("finishButtonTapped calls setBool and sends delegate")
    func testFinishButtonTapped() async throws {
        let capturedSetBool = LockIsolated(
            (called: false, value: Bool?.none, keyRawValue: String?.none)
        )

        let store = await TestStore(
            initialState: OnboardingFeature.State(currentStep: .ready)
        ) {
            OnboardingFeature()
        } withDependencies: {
            $0.userSettingsClient.setBool = { value, key in
                capturedSetBool.withValue {
                    $0.called = true
                    $0.value = value
                    $0.keyRawValue = key.rawValue
                }
            }
        }

        await store.send(.finishButtonTapped)
        await store.receive(\.delegate.onboardingCompleted)

        let recorded = capturedSetBool.value
        #expect(recorded.called == true)
        #expect(recorded.value == true)
        #expect(recorded.keyRawValue == SettingsKey.hasCompletedOnboarding.rawValue)
    }

    // MARK: - Binding

    @Test("binding updates accountName without side effects")
    func testBindingAccountName() async throws {
        let store = await TestStore(
            initialState: OnboardingFeature.State()
        ) {
            OnboardingFeature()
        }

        await store.send(\.binding.accountName, "銀行帳戶") {
            $0.accountName = "銀行帳戶"
        }
    }

    @Test("binding updates accountType without side effects")
    func testBindingAccountType() async throws {
        let store = await TestStore(
            initialState: OnboardingFeature.State()
        ) {
            OnboardingFeature()
        }

        await store.send(\.binding.accountType, .bank) {
            $0.accountType = .bank
        }
    }
}
