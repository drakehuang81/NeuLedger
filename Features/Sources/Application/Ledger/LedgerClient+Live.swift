import Foundation
import Dependencies
import Domain

/// Live implementation of `LedgerClient` — step-5a1 delegating skeleton.
///
/// Every closure forwards to the still-living UseCases/repositories so the
/// switchover (step 5b) is behavior-preserving. This transitional dependency
/// on the old types is intentional and short-lived: subsequent commits
/// internalise each section onto `SwiftDataStore` directly and lift the
/// post-conditions (budget evaluation, widget/watch mirroring, recurring
/// reminders) into this client. Because the lifetime is bounded to the
/// expansion phase, these delegations carry no `// INVARIANT:` annotation
/// (per plan §A.6 "Live 漸進組裝策略").
///
/// Section → delegate target (plan 5a1 mapping):
/// - Transactions → `\.ledger` (LedgerUseCase), method-for-method.
/// - Accounts → `\.accountClient` (repo) for CRUD/reads/balance,
///   `\.accountUseCase` for `unarchive` + `balances`, and
///   `\.userSettingsAdapter` (`.defaultAccountId` key) for the default account.
/// - Catalog → `\.metadataUseCase`, method-for-method.
/// - Recurring → `\.recurringTransactionClient` (CRUD/list) + `\.recurringUseCase` (`tick`).
/// - Export → `\.exportUseCase.exportTransactionsCSV`.
extension LedgerClient: DependencyKey {
    public static var liveValue: LedgerClient {
        @Dependency(\.ledger) var ledger
        @Dependency(\.accountClient) var accountClient
        @Dependency(\.accountUseCase) var accountUseCase
        @Dependency(\.metadataUseCase) var metadataUseCase
        @Dependency(\.recurringTransactionClient) var recurringTransactionClient
        @Dependency(\.recurringUseCase) var recurringUseCase
        @Dependency(\.exportUseCase) var exportUseCase
        @Dependency(\.userSettingsAdapter) var userSettingsAdapter

        return LedgerClient(
            // MARK: Transactions
            record: { transaction in
                try await ledger.record(transaction)
            },
            update: { transaction in
                try await ledger.update(transaction)
            },
            delete: { id in
                try await ledger.delete(id)
            },
            fetch: { id in
                try await ledger.fetch(id)
            },
            listRecent: { limit in
                try await ledger.listRecent(limit)
            },
            listAll: { filter in
                try await ledger.listAll(filter)
            },
            search: { query in
                try await ledger.search(query)
            },

            // MARK: Accounts
            setupAccounts: { accounts in
                try await accountClient.setupAccounts(accounts)
            },
            createAccount: { account in
                try await accountClient.add(account)
            },
            updateAccount: { account in
                try await accountClient.update(account)
            },
            archiveAccount: { id in
                try await accountClient.archive(id)
            },
            unarchiveAccount: { id in
                try await accountUseCase.unarchive(id)
            },
            deleteAccount: { id in
                try await accountClient.delete(id)
            },
            listAccounts: {
                try await accountClient.fetchAll()
            },
            listActiveAccounts: {
                try await accountClient.fetchActive()
            },
            balance: { id in
                try await accountClient.computeBalance(id)
            },
            balances: {
                try await accountUseCase.balances()
            },
            defaultAccountId: {
                let raw = userSettingsAdapter.string(.defaultAccountId)
                return raw.isEmpty ? nil : raw
            },
            setDefaultAccountId: { id in
                userSettingsAdapter.setString(id ?? "", .defaultAccountId)
            },

            // MARK: Catalog
            listCategories: { type in
                try await metadataUseCase.listCategories(type)
            },
            createCategory: { category in
                try await metadataUseCase.createCategory(category)
            },
            updateCategory: { category in
                try await metadataUseCase.updateCategory(category)
            },
            deleteCategory: { id in
                try await metadataUseCase.deleteCategory(id)
            },
            listTags: {
                try await metadataUseCase.listTags()
            },
            createTag: { tag in
                try await metadataUseCase.createTag(tag)
            },
            updateTag: { tag in
                try await metadataUseCase.updateTag(tag)
            },
            deleteTag: { id in
                try await metadataUseCase.deleteTag(id)
            },

            // MARK: Recurring
            listRecurring: {
                try await recurringTransactionClient.fetchAll()
            },
            createRecurring: { template in
                try await recurringTransactionClient.add(template)
            },
            updateRecurring: { template in
                try await recurringTransactionClient.update(template)
            },
            deleteRecurring: { id in
                try await recurringTransactionClient.delete(id)
            },
            tick: {
                try await recurringUseCase.tick()
            },

            // MARK: Export
            exportCSV: {
                try await exportUseCase.exportTransactionsCSV()
            }
        )
    }
}
