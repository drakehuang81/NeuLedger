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

    @Test("recurringConfirmation route opens dashboard confirmation when in main")
    func recurringConfirmationRoutesInMain() async {
        let template = RecurringTransaction(
            id: UUID(), amount: 15000, note: "房租",
            categoryId: nil, accountId: UUID().uuidString, toAccountId: nil,
            type: .expense, tags: [], frequency: .monthly,
            nextDueDate: Date(), isActive: true, createdAt: Date()
        )
        let store = await TestStore(initialState: .main(MainTabFeature.State())) {
            AppFeature()
        }
        await MainActor.run { store.exhaustivity = .off }
        await store.send(.route(.recurringConfirmation(template))) { state in
            guard case let .main(main) = state else {
                Issue.record("expected .main state")
                return
            }
            #expect(main.selectedTab == .dashboard)
            #expect(main.dashboard.addTransaction?.mode == .addRecurringConfirmation(template))
        }
    }

    @Test("recurringConfirmation route is ignored when not in main")
    func recurringConfirmationIgnoredOutsideMain() async {
        let template = RecurringTransaction(
            id: UUID(), amount: 15000, note: "房租",
            categoryId: nil, accountId: UUID().uuidString, toAccountId: nil,
            type: .expense, tags: [], frequency: .monthly,
            nextDueDate: Date(), isActive: true, createdAt: Date()
        )
        let store = await TestStore(initialState: .onboarding(OnboardingFeature.State())) {
            AppFeature()
        }
        // guard case .main fails → no-op, no state change
        await store.send(.route(.recurringConfirmation(template)))
    }

    @Test("task routes a tapped recurring confirmation")
    func taskRoutesRecurringConfirmation() async {
        let template = RecurringTransaction(
            id: UUID(), amount: 15000, note: "房租",
            categoryId: nil, accountId: UUID().uuidString, toAccountId: nil,
            type: .expense, tags: [], frequency: .monthly,
            nextDueDate: Date(), isActive: true, createdAt: Date()
        )
        let store = await TestStore(initialState: .main(MainTabFeature.State())) {
            AppFeature()
        } withDependencies: {
            $0.platformClient.pendingRecurringConfirmations = {
                AsyncStream { continuation in
                    continuation.yield(template.id)
                    continuation.finish()
                }
            }
            $0.platformClient.resolveRecurringConfirmation = { _ in .recurringConfirmation(template) }
        }
        await MainActor.run { store.exhaustivity = .off }
        await store.send(.task)
        await store.receive(\.route) { state in
            guard case let .main(main) = state else {
                Issue.record("expected .main state")
                return
            }
            #expect(main.dashboard.addTransaction?.mode == .addRecurringConfirmation(template))
        }
        await store.finish()
    }

    @Test("task ignores a confirmation that resolves to none")
    func taskIgnoresUnresolvedConfirmation() async {
        let store = await TestStore(initialState: .main(MainTabFeature.State())) {
            AppFeature()
        } withDependencies: {
            $0.platformClient.pendingRecurringConfirmations = {
                AsyncStream { continuation in
                    continuation.yield(UUID())
                    continuation.finish()
                }
            }
            $0.platformClient.resolveRecurringConfirmation = { _ in .none }
        }
        await store.send(.task)
        await store.receive(\.route)
        await store.finish()
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
}
