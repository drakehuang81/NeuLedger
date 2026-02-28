import ComposableArchitecture
import Testing
@testable import Features

@Suite("AppFeature Tests")
struct AppFeatureTests {
    
    @Test("App logic onAppear routes to main if onboarding is completed")
    func onAppearRoutesToMain() async {
        let store = await TestStore(
            initialState: AppFeature.State()
        ) {
            AppFeature()
        } withDependencies: {
            $0.userSettingsClient.bool = { _ in true }
        }
        
        await store.send(\.onAppear) {
            $0.destination = .main(MainTabFeature.State())
        }
    }
    
    @Test("App logic onAppear routes to onboarding if onboarding is not completed")
    func onAppearRoutesToOnboarding() async {
        let store = await TestStore(
            initialState: AppFeature.State()
        ) {
            AppFeature()
        } withDependencies: {
            $0.userSettingsClient.bool = { _ in false }
        }
        
        await store.send(\.onAppear) {
            $0.destination = .onboarding(OnboardingFeature.State())
        }
    }

    @Test("Onboarding completion routes to main")
    func onboardingCompletedRoutesToMain() async {
        let store = await TestStore(
            initialState: AppFeature.State(destination: .onboarding(OnboardingFeature.State()))
        ) {
            AppFeature()
        }
        
        await store.send(\.onboarding.delegate.onboardingCompleted) {
            $0.destination = .main(MainTabFeature.State())
        }
    }
}
