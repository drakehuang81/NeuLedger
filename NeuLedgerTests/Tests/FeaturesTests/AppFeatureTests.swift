import ComposableArchitecture
import Domain
import Testing
@testable import Features

@Suite("AppFeature Tests")
struct AppFeatureTests {

    @Test("splashCompleted routes to main if onboarding can be skipped")
    func splashCompletedRoutesToMain() async {
        let store = await TestStore(
            initialState: AppFeature.State()
        ) {
            AppFeature()
        } withDependencies: {
            $0.deeplinkClient.canSkipOnboarding = { true }
        }

        await store.send(\.splashCompleted)
        await store.receive(\.route.main) {
            $0 = .main(MainTabFeature.State())
        }
    }

    @Test("splashCompleted routes to onboarding if onboarding cannot be skipped")
    func splashCompletedRoutesToOnboarding() async {
        let store = await TestStore(
            initialState: AppFeature.State()
        ) {
            AppFeature()
        } withDependencies: {
            $0.deeplinkClient.canSkipOnboarding = { false }
        }

        await store.send(\.splashCompleted)
        await store.receive(\.route.onboarding) {
            $0 = .onboarding(OnboardingFeature.State())
        }
    }

    @Test("Onboarding completion routes to main")
    func onboardingCompletedRoutesToMain() async {
        let store = await TestStore(
            initialState: AppFeature.State.onboarding(OnboardingFeature.State())
        ) {
            AppFeature()
        }

        await store.send(\.onboarding.delegate.onboardingCompleted)
        await store.receive(\.route.main) {
            $0 = .main(MainTabFeature.State())
        }
    }
}
