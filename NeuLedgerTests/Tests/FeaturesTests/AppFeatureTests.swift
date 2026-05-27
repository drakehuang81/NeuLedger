import ComposableArchitecture
import Domain
import Testing
@testable import Features

@Suite("AppFeature Tests")
struct AppFeatureTests {
    
    @Test("splashCompleted routes to main if onboarding is completed")
    func splashCompletedRoutesToMain() async {
        let store = await TestStore(
            initialState: AppFeature.State()
        ) {
            AppFeature()
        } withDependencies: {
            $0.userSettingsAdapter.bool = { _ in true }
        }

        await store.send(\.splashCompleted) {
            $0 = .main(MainTabFeature.State())
        }
    }

    @Test("splashCompleted routes to onboarding if onboarding is not completed")
    func splashCompletedRoutesToOnboarding() async {
        let store = await TestStore(
            initialState: AppFeature.State()
        ) {
            AppFeature()
        } withDependencies: {
            $0.userSettingsAdapter.bool = { _ in false }
        }

        await store.send(\.splashCompleted) {
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

        await store.send(\.onboarding.delegate.onboardingCompleted) {
            $0 = .main(MainTabFeature.State())
        }
    }
}
