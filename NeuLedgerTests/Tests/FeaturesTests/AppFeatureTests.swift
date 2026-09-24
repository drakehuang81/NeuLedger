import ComposableArchitecture
import Domain
import Foundation
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
            $0.platformClient.canSkipOnboarding = { true }
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
            $0.platformClient.canSkipOnboarding = { false }
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

    // MARK: - Deep Link Tests

    @Test("deepLinkReceived with carrierManagement destination sets settings tab and appends path")
    func deepLinkCarrierManagementLandsInSettings() async {
        let url = URL(string: "neuledger://carrier-management")!
        let store = await TestStore(initialState: .main(MainTabFeature.State())) {
            AppFeature()
        } withDependencies: {
            $0.platformClient.parseLink = { _ in .carrierManagement }
        }
        await MainActor.run { store.exhaustivity = .off }
        await store.send(.deepLinkReceived(url))
        await store.receive(\.route.carrierManagement) { state in
            guard case let .main(main) = state else {
                Issue.record("expected .main state")
                return
            }
            #expect(main.selectedTab == .settings)
            #expect(!main.settings.path.isEmpty)
        }
    }

    @Test("deepLinkReceived with none destination does not change state")
    func deepLinkNoneDestinationNoOp() async {
        let url = URL(string: "neuledger://unknown")!
        let store = await TestStore(initialState: AppFeature.State.main(MainTabFeature.State())) {
            AppFeature()
        } withDependencies: {
            $0.platformClient.parseLink = { _ in .none }
        }
        await store.send(.deepLinkReceived(url))
        // route(.none) hits the default branch — no state mutation; just verify action received
        await store.receive(\.route)
    }

    @Test("route carrierManagement is a no-op when destination is not main")
    func routeCarrierManagementIgnoredOutsideMain() async {
        let store = await TestStore(initialState: .onboarding(OnboardingFeature.State())) {
            AppFeature()
        }
        // guard case .main fails → early return, no state change
        await store.send(.route(.carrierManagement))
    }

    @Test("allDataWiped delegate resets destination to onboarding")
    func allDataWipedResetsToOnboarding() async {
        let store = await TestStore(initialState: .main(MainTabFeature.State())) {
            AppFeature()
        }
        await store.send(.main(.settings(.delegate(.allDataWiped))))
        await store.receive(\.route.onboarding) {
            $0 = .onboarding(OnboardingFeature.State())
        }
    }

    // MARK: - Splash / deep-link error fallback (health-audit A4)

    private struct StubError: LocalizedError { var errorDescription: String? { "boom" } }

    @Test("splashCompleted falls back to onboarding when canSkipOnboarding throws")
    func testSplashFallsBackToOnboarding() async {
        let store = await TestStore(
            initialState: AppFeature.State()
        ) {
            AppFeature()
        } withDependencies: {
            $0.platformClient.canSkipOnboarding = { throw StubError() }
        }

        await store.send(\.splashCompleted)
        await store.receive(\.route.onboarding) {
            $0 = .onboarding(OnboardingFeature.State())
        }
    }

    @Test("deepLinkReceived ignores a link that fails to parse")
    func testDeepLinkParseFailureIsIgnored() async {
        let store = await TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.platformClient.parseLink = { _ in throw StubError() }
        }
        await store.send(.deepLinkReceived(URL(string: "neuledger://nope")!))
        await store.finish()
    }
}
