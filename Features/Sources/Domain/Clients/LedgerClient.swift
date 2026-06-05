import Foundation
import Dependencies
import DependenciesMacros

/// The single domain client for the ledger aggregate — transactions, accounts,
/// catalog (categories + tags), recurring templates, and export.
///
/// `LedgerClient` consolidates what previously lived across five UseCases
/// (`LedgerUseCase`, `AccountUseCase`, `MetadataUseCase`, `RecurringUseCase`,
/// `ExportUseCase`) and five repositories (`TransactionClient`, `AccountClient`,
/// `CategoryClient`, `TagClient`, `RecurringTransactionClient`). The Features
/// layer drives all ledger concerns through this single client.
///
/// This is the step-5a1 surface: the interface plus a delegating live value
/// that forwards every closure to the still-living UseCases/repositories, so
/// behavior is byte-for-byte unchanged. Subsequent steps internalise each
/// section onto `SwiftDataStore` directly and lift post-conditions (budget
/// evaluation, widget/watch mirroring, recurring reminders) into this client.
@DependencyClient
public struct LedgerClient: Sendable {

    // MARK: - Transactions

    public var record: @Sendable (_ transaction: Transaction) async throws -> Void
    public var update: @Sendable (_ transaction: Transaction) async throws -> Void
    public var delete: @Sendable (_ id: Transaction.ID) async throws -> Void
    public var fetch: @Sendable (_ id: Transaction.ID) async throws -> EnrichedTransaction?
    public var listRecent: @Sendable (_ limit: Int) async throws -> [EnrichedTransaction] = { _ in [] }
    public var listAll: @Sendable (_ filter: TransactionFilter) async throws -> [EnrichedTransaction] = { _ in [] }
    public var search: @Sendable (_ query: String) async throws -> [EnrichedTransaction] = { _ in [] }

    // MARK: - Accounts

    public var setupAccounts: @Sendable (_ accounts: [Account]) async throws -> Void
    public var createAccount: @Sendable (_ account: Account) async throws -> Void
    public var updateAccount: @Sendable (_ account: Account) async throws -> Void
    public var archiveAccount: @Sendable (_ id: Account.ID) async throws -> Void
    public var unarchiveAccount: @Sendable (_ id: Account.ID) async throws -> Void
    public var deleteAccount: @Sendable (_ id: Account.ID) async throws -> Void
    public var listAccounts: @Sendable () async throws -> [Account]
    public var listActiveAccounts: @Sendable () async throws -> [Account]
    public var balance: @Sendable (_ id: Account.ID) async throws -> Decimal
    public var balances: @Sendable () async throws -> [Account.ID: Decimal]
    public var defaultAccountId: @Sendable () -> Account.ID? = { nil }
    public var setDefaultAccountId: @Sendable (_ id: Account.ID?) -> Void

    // MARK: - Catalog

    public var listCategories: @Sendable (_ type: TransactionType?) async throws -> [Category] = { _ in [] }
    public var createCategory: @Sendable (_ category: Category) async throws -> Void
    public var updateCategory: @Sendable (_ category: Category) async throws -> Void
    public var deleteCategory: @Sendable (_ id: Category.ID) async throws -> Void
    public var listTags: @Sendable () async throws -> [Tag]
    public var createTag: @Sendable (_ tag: Tag) async throws -> Void
    public var updateTag: @Sendable (_ tag: Tag) async throws -> Void
    public var deleteTag: @Sendable (_ id: Tag.ID) async throws -> Void

    // MARK: - Recurring（自動記帳）

    public var listRecurring: @Sendable () async throws -> [RecurringTransaction]
    public var createRecurring: @Sendable (_ template: RecurringTransaction) async throws -> Void
    public var updateRecurring: @Sendable (_ template: RecurringTransaction) async throws -> Void
    public var deleteRecurring: @Sendable (_ id: RecurringTransaction.ID) async throws -> Void
    public var tick: @Sendable () async throws -> Void

    // MARK: - Export

    public var exportCSV: @Sendable () async throws -> URL
}

// MARK: - TestDependencyKey

extension LedgerClient: TestDependencyKey {
    public static let testValue = Self()
}

// MARK: - DependencyValues

public extension DependencyValues {
    var ledgerClient: LedgerClient {
        get { self[LedgerClient.self] }
        set { self[LedgerClient.self] = newValue }
    }
}
