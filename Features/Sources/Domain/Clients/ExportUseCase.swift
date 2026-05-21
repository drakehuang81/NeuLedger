import Foundation
import Dependencies
import DependenciesMacros

/// Application-layer use case for exporting ledger data to file
/// formats consumable by external tools.
///
/// Surface follows `docs/architecture.md` §5. CSV is the only format
/// in the target spec — the previous JSON path lives only in
/// `SettingsFeature` and is not promoted to a UseCase concern.
@DependencyClient
public struct ExportUseCase: Sendable {
    /// Build a CSV containing every transaction (date / type /
    /// category / note / amount / account) joined against the
    /// resolved category and account names. Writes to the system
    /// temporary directory and returns the file URL.
    public var exportTransactionsCSV: @Sendable () async throws -> URL = {
        URL(fileURLWithPath: "/dev/null")
    }
}

extension ExportUseCase: TestDependencyKey {
    public static let testValue = Self()
}

public extension DependencyValues {
    var exportUseCase: ExportUseCase {
        get { self[ExportUseCase.self] }
        set { self[ExportUseCase.self] = newValue }
    }
}
