import Foundation
import Dependencies
import DependenciesMacros

/// A client interface for synchronising carrier data to the Widget Extension
/// via the App Group container and requesting a WidgetKit timeline reload.
///
/// The Features layer must **never** import `WidgetKit` or access `UserDefaults(suiteName:)`
/// directly. All widget sync operations go through this client.
@DependencyClient
public struct WidgetSyncAdapter: Sendable {
    /// Writes carrier data to the shared App Group container and triggers a
    /// WidgetKit timeline reload so the `CarrierWidget` reflects the latest carrier.
    public var syncCarrier: @Sendable (_ barcode: String, _ type: String, _ name: String) async -> Void

    /// Removes all carrier data from the shared App Group container and triggers
    /// a WidgetKit timeline reload so the `CarrierWidget` shows the empty state.
    public var clearCarrier: @Sendable () async -> Void

    /// Writes the full list of carriers to the App Group as JSON and triggers
    /// a CarrierWidget timeline reload. Called after every CRUD operation in
    /// `CarrierManagementFeature` so configurable widgets can resolve their
    /// bound carrier by ID.
    public var syncAllCarriers: @Sendable (_ carriers: [Carrier]) async -> Void
}

extension WidgetSyncAdapter: TestDependencyKey {
    public static let testValue = Self()
}

public extension DependencyValues {
    var widgetSyncAdapter: WidgetSyncAdapter {
        get { self[WidgetSyncAdapter.self] }
        set { self[WidgetSyncAdapter.self] = newValue }
    }
}
