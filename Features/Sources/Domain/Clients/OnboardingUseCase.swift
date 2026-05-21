import Foundation
import Dependencies
import DependenciesMacros

/// Application-layer use case for the one-shot onboarding flow.
///
/// Surface follows `docs/architecture.md` §5. Exposes a single
/// `complete(firstAccount:)` entry point that creates the user's first
/// account and flips the `hasCompletedOnboarding` preference.
///
/// Per architecture.md §5, the Live implementation calls
/// `accountClient.add` directly — there's no §3.1 whitelist reason to
/// route through `AccountUseCase` (onboarding is a single-machine
/// initialization, not a recurring invariant chain). The
/// onboarding-complete flag flips through `AppEnvironmentUseCase` so the
/// "what counts as onboarded" definition stays single-sourced.
@DependencyClient
public struct OnboardingUseCase: Sendable {
    public var complete: @Sendable (_ firstAccount: Account) async throws -> Void
}

extension OnboardingUseCase: TestDependencyKey {
    public static let testValue = Self()
}

public extension DependencyValues {
    var onboardingUseCase: OnboardingUseCase {
        get { self[OnboardingUseCase.self] }
        set { self[OnboardingUseCase.self] = newValue }
    }
}
