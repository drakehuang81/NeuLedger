import Foundation
import Dependencies
import DependenciesMacros

/// Application-layer use case for Taiwan e-invoice carrier records +
/// the home-screen widget association.
///
/// Surface follows `docs/architecture.md` §5 Carrier Context. CRUD
/// delegates to `CarrierClient`; the widget-active selection persists
/// via `UserSettingsRepository` under the existing `.widgetCarrierId`
/// SettingsKey (UserDefaults storage — survives app/widget restarts).
@DependencyClient
public struct CarrierUseCase: Sendable {
    public var listAll: @Sendable () async throws -> [Carrier]
    public var create: @Sendable (_ carrier: Carrier) async throws -> Void
    public var update: @Sendable (_ carrier: Carrier) async throws -> Void
    public var delete: @Sendable (_ id: Carrier.ID) async throws -> Void

    /// Persist the user's widget-active carrier choice. Async signature
    /// reserved per architecture.md §5 even though today's storage is
    /// sync UserDefaults — future widget timeline reload work may need
    /// it.
    public var setActiveForWidget: @Sendable (_ id: Carrier.ID) async -> Void

    /// Read the currently widget-active carrier id, or `nil` if none has
    /// been chosen.
    public var activeForWidget: @Sendable () -> Carrier.ID? = { nil }
}

extension CarrierUseCase: TestDependencyKey {
    public static let testValue = Self()
}

public extension DependencyValues {
    var carrierUseCase: CarrierUseCase {
        get { self[CarrierUseCase.self] }
        set { self[CarrierUseCase.self] = newValue }
    }
}
