import Foundation
import CasePaths

// MARK: - RouteLinkDestination

/// A resolved navigation destination derived from an inbound link
/// (URL deeplink, recurring-transaction notification, or onboarding gate).
///
/// Relocated from `Domain/UseCases/DeeplinkClient.swift` into the shared
/// `ValueObjects` folder as part of the client-layer consolidation
/// (`PlatformClient` absorbs the former `DeeplinkClient` surface). The
/// type and its cases are unchanged.
@CasePathable
public enum RouteLinkDestination: Sendable, Equatable {
    case carrierManagement
    case recurringConfirmation(RecurringTransaction)
    case main
    case onboarding
    case none
}
