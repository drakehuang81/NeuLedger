import ComposableArchitecture
import Testing
@testable import Features

@Suite("AppFeature Tests")
struct AppFeatureTests {
    
    @Test("Onboarding completion routes to main")
    func onboardingCompletedRoutesToMain() async {
        let store = TestStore(
            initialState: AppFeature.State(destination: .onboarding(OnboardingFeature.State()))
        ) {
            AppFeature()
        }
        
        await store.send(\.onboarding.delegate.onboardingCompleted) {
            $0.destination = .main
        }
    }
}
