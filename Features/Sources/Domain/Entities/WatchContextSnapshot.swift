import Foundation

/// The minimum-viable state the watchOS app needs to render its UI and
/// Complication without consulting SwiftData directly.
///
/// Built on iPhone via `WatchContextBuilder`, pushed across via
/// `WatchBridgeAdapter.pushContext`. The iPhone always sends a full
/// snapshot (not a delta) because `WCSession.updateApplicationContext`
/// only retains the latest one — so partial snapshots would lose data
/// on a rapid burst of writes.
public struct WatchContextSnapshot: Equatable, Codable, Sendable {
    /// Expense + income categories the Watch should render in its picker.
    public let categories: [Category]

    /// Non-archived accounts available for selection on Watch.
    public let accounts: [Account]

    /// The account id used when the user records on Watch without
    /// explicitly selecting one (the long-press-to-pick path overrides
    /// per-draft).
    public let defaultAccountId: Account.ID

    /// Sum of today's expenses, used by the Watch app header and the
    /// `TodayExpenseComplication`.
    public let todayTotal: Decimal

    /// Number of expense transactions recorded today.
    public let todayCount: Int

    /// Share of the active overall monthly budget consumed so far this
    /// month. `nil` when no overall monthly budget is configured.
    public let monthBudgetProgress: Double?

    /// When this snapshot was assembled on iPhone.
    public let snapshotAt: Date

    /// E-invoice carriers mirrored for the Watch carrier page, in the
    /// iPhone list order. `nil` when the snapshot came from an older
    /// iPhone build without carrier support (Watch shows a sync hint);
    /// empty when the user genuinely has none (Watch shows add-on-iPhone
    /// guidance). Optional so legacy cached JSON keeps decoding.
    public let carriers: [Carrier]?

    public init(
        categories: [Category],
        accounts: [Account],
        defaultAccountId: Account.ID,
        todayTotal: Decimal,
        todayCount: Int,
        monthBudgetProgress: Double?,
        snapshotAt: Date,
        carriers: [Carrier]? = nil
    ) {
        self.categories = categories
        self.accounts = accounts
        self.defaultAccountId = defaultAccountId
        self.todayTotal = todayTotal
        self.todayCount = todayCount
        self.monthBudgetProgress = monthBudgetProgress
        self.snapshotAt = snapshotAt
        self.carriers = carriers
    }
}
