import Foundation
import SwiftData
import Domain
import Dependencies

/// Live implementation of `AccountClient` backed by `SwiftDataStore`.
extension AccountClient: DependencyKey {
    public static var liveValue: AccountClient {
        let accountStore = SwiftDataStore<Account, SDAccount>()
        let transactionStore = SwiftDataStore<Transaction, SDTransaction>()

        @Dependency(\.userSettingsAdapter) var userSettingsAdapter

        return AccountClient(
            setupAccounts: { newAccount in
                
                let exsiting = (try? await accountStore.fetchAll(sortBy: [SortDescriptor(\.sortOrder)])) ?? []

                var dictionary = Dictionary(uniqueKeysWithValues: newAccount.map { ($0.id, $0)})

                exsiting.forEach { account in
                    if dictionary[account.id] != nil {
                        // remove exsiting account from database
                        dictionary.removeValue(forKey: account.id)
                    }
                }
                // TODO: batch, error handle
                for account in dictionary.values {
                    try await accountStore.add(account)
                }
                userSettingsAdapter.setBool(true, .hasCompletedOnboarding)
            },
            fetchAll: {
                try await accountStore.fetchAll(sortBy: [SortDescriptor(\.sortOrder)])
            },
            fetchActive: {
                try await accountStore.fetchAll(sortBy: [SortDescriptor(\.sortOrder)])
                    .filter { !$0.isArchived }
            },
            computeBalance: { accountId in
                let transactions = try await transactionStore.fetchAll()
                var balance: Decimal = 0
                for txn in transactions {
                    switch txn.type {
                    case .income:
                        if txn.accountId == accountId { balance += txn.amount }
                    case .expense:
                        if txn.accountId == accountId { balance -= txn.amount }
                    case .transfer:
                        if txn.accountId == accountId { balance -= txn.amount }
                        if txn.toAccountId == accountId { balance += txn.amount }
                    }
                }
                return balance
            },
            add: { account in
                try await accountStore.add(account)
            },
            update: { account in
                try await accountStore.update(account)
            },
            archive: { id in
                guard var existing = try await accountStore.fetch(id: id) else {
                    throw CoreError.notFound("SDAccount")
                }
                existing.isArchived = true
                try await accountStore.update(existing)
            },
            delete: { id in
                let hasLinkedTransactions = try await transactionStore.fetchAll().contains {
                    $0.accountId == id || $0.toAccountId == id
                }
                guard !hasLinkedTransactions else {
                    throw CoreError.operationDenied(
                        "Cannot delete account with associated transactions; archive it instead."
                    )
                }
                try await accountStore.delete(id: id)
            }
        )
    }
}
