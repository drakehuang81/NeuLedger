import Foundation
import CasePaths

// MARK: - RouteLinkDestination

/// A resolved navigation destination derived from an inbound link
/// (URL deeplink or onboarding gate). Recurring-transaction due dates no
/// longer route through here — they auto-record via `MainTabFeature`'s
/// foreground `tick()` instead of a notification-confirmation deep link.
///
/// Relocated from `Domain/UseCases/DeeplinkClient.swift` into the shared
/// `ValueObjects` folder as part of the client-layer consolidation
/// (`PlatformClient` absorbs the former `DeeplinkClient` surface). The
/// type and its cases are unchanged.
@CasePathable
public enum RouteLinkDestination: Sendable, Equatable {
    case carrierManagement
    case main
    case onboarding
    case none
}
