import Foundation
import Dependencies
import Domain

extension OnboardingUseCase: DependencyKey {
    public static var liveValue: OnboardingUseCase {
        @Dependency(\.accountClient) var accountClient
        @Dependency(\.appEnvironmentUseCase) var appEnvironmentUseCase

        return OnboardingUseCase(
            complete: { firstAccount in
                // Direct Repository call (architecture.md §5) — onboarding
                // is a one-shot initialization, not a recurring invariant
                // chain, so there's no §3.1 whitelist reason to detour
                // through AccountUseCase.
                try await accountClient.add(firstAccount)

                // Single source of truth for "user is onboarded".
                appEnvironmentUseCase.markOnboardingComplete()
            }
        )
    }
}
