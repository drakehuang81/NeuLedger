import Testing
import Foundation
import ComposableArchitecture
import Domain
@testable import Features

@Suite("AccountManagementFeature Tests")
struct AccountManagementFeatureTests {

    // MARK: - Helpers

    private static let cashAccount = Account(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        name: "現金", type: .cash, icon: "banknote", color: "#34C759", sortOrder: 0
    )
    private static let bankAccount = Account(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        name: "銀行", type: .bank, icon: "building.columns", color: "#3478F6", sortOrder: 1
    )
    private static let archivedAccount = Account(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
        name: "舊帳戶", type: .cash, icon: "creditcard", color: "#8E8E93", sortOrder: 2,
        isArchived: true
    )

    // MARK: - Load Accounts

    @Test("task loads all accounts and then fetches balances")
    func testTaskLoadsAccountsAndBalances() async throws {
        let accounts = [Self.cashAccount, Self.bankAccount]

        let store = await TestStore(
            initialState: AccountManagementFeature.State()
        ) {
            AccountManagementFeature()
        } withDependencies: {
            $0.accountClient.fetchAll = { accounts }
            $0.accountClient.computeBalance = { id in
                id == Self.cashAccount.id ? 1000 : 5000
            }
        }

        await store.send(.task) { $0.isLoading = true }

        await store.receive(\.accountsLoaded) {
            $0.isLoading = false
            $0.accounts = accounts
        }

        await store.receive(\.balancesLoaded) {
            $0.balances = [Self.cashAccount.id: 1000, Self.bankAccount.id: 5000]
        }
    }

    @Test("activeAccounts excludes archived accounts")
    func testActiveAccountsComputed() async {
        var state = AccountManagementFeature.State()
        state.accounts = [Self.cashAccount, Self.bankAccount, Self.archivedAccount]
        #expect(state.activeAccounts.count == 2)
        #expect(state.archivedAccounts.count == 1)
        #expect(state.archivedAccounts.first?.name == "舊帳戶")
    }

    // MARK: - Add Account

    @Test("addButtonTapped presents add form with existing names")
    func testAddButtonTapped() async throws {
        var initialState = AccountManagementFeature.State()
        initialState.accounts = [Self.cashAccount, Self.bankAccount]

        let store = await TestStore(initialState: initialState) {
            AccountManagementFeature()
        }

        await store.send(.addButtonTapped) {
            $0.addEdit = AddEditAccountFeature.State(
                mode: .add,
                existingNames: ["現金", "銀行"]
            )
        }

        await store.send(\.addEdit.dismiss) {
            $0.addEdit = nil
        }
    }

    // MARK: - Validation: Empty Name

    @Test("saveTapped with empty name sets nameError inline")
    func testAddAccountEmptyNameValidation() async throws {
        let store = await TestStore(
            initialState: AddEditAccountFeature.State(mode: .add)
        ) {
            AddEditAccountFeature()
        }

        await store.send(.saveTapped) {
            $0.nameError = String(localized: "error_account_name_empty")
        }
    }

    // MARK: - Validation: Duplicate Name

    @Test("saveTapped with duplicate name sets nameError inline")
    func testAddAccountDuplicateNameValidation() async throws {
        let store = await TestStore(
            initialState: AddEditAccountFeature.State(
                mode: .add,
                existingNames: ["現金"]
            )
        ) {
            AddEditAccountFeature()
        }

        await store.send(.nameChanged("現金")) { $0.name = "現金" }
        await store.send(.saveTapped) {
            $0.nameError = String(localized: "error_account_name_taken")
        }
    }

    // MARK: - Archive Flow (account has transactions)

    @Test("deleteRequested with transactions shows archive confirmation")
    func testDeleteRequestedWithTransactionsShowsArchive() async throws {
        let id = Self.cashAccount.id
        var initialState = AccountManagementFeature.State()
        initialState.accounts = [Self.cashAccount]

        let store = await TestStore(initialState: initialState) {
            AccountManagementFeature()
        } withDependencies: {
            $0.transactionClient.fetch = { _ in
                [Transaction(amount: 100, date: Date(), accountId: id, type: .expense)]
            }
        }

        await store.send(.deleteRequested(id))
        await store.receive(\.showArchiveConfirmation) {
            $0.alert = AlertState {
                TextState(String(localized: "alert_cannot_delete"))
            } actions: {
                ButtonState(action: AccountManagementFeature.Action.Alert.archiveConfirmed(id)) {
                    TextState(String(localized: "alert_archive_instead"))
                }
                ButtonState(role: .cancel) {
                    TextState(String(localized: "common_cancel"))
                }
            } message: {
                TextState(String(localized: "alert_archive_account_message"))
            }
        }
    }

    // MARK: - Delete Flow (no transactions)

    @Test("deleteRequested with no transactions shows delete confirmation")
    func testDeleteRequestedWithNoTransactionsShowsDelete() async throws {
        let id = Self.cashAccount.id
        var initialState = AccountManagementFeature.State()
        initialState.accounts = [Self.cashAccount]

        let store = await TestStore(initialState: initialState) {
            AccountManagementFeature()
        } withDependencies: {
            $0.transactionClient.fetch = { _ in [] }
        }

        await store.send(.deleteRequested(id))
        await store.receive(\.showDeleteConfirmation) {
            $0.alert = AlertState {
                TextState(String(localized: "alert_confirm_delete"))
            } actions: {
                ButtonState(role: .destructive, action: AccountManagementFeature.Action.Alert.deleteConfirmed(id)) {
                    TextState(String(localized: "common_delete"))
                }
                ButtonState(role: .cancel) {
                    TextState(String(localized: "common_cancel"))
                }
            } message: {
                TextState(String(localized: "alert_delete_account_message"))
            }
        }
    }

    // MARK: - Full Delete Confirmation Chain (P1-B)

    @Test("deleteConfirmed calls accountClient.delete and reloads remaining accounts")
    func testDeleteConfirmedCallsDeleteAndReloadsAccounts() async throws {
        let deletedId: LockIsolated<Account.ID?> = LockIsolated(nil)
        let id = Self.cashAccount.id

        // Alert must be present for .alert(.presented(...)) to route through ifLet
        var initialState = AccountManagementFeature.State()
        initialState.accounts = [Self.cashAccount, Self.bankAccount]
        initialState.alert = AlertState {
            TextState(String(localized: "alert_confirm_delete"))
        } actions: {
            ButtonState(role: .destructive, action: .deleteConfirmed(id)) {
                TextState(String(localized: "common_delete"))
            }
            ButtonState(role: .cancel) {
                TextState(String(localized: "common_cancel"))
            }
        } message: {
            TextState(String(localized: "alert_delete_account_message"))
        }

        let store = await TestStore(initialState: initialState) {
            AccountManagementFeature()
        } withDependencies: {
            $0.accountClient.delete = { deletedId.setValue($0) }
            // After delete, fetchAll returns only the bank account (1 remaining)
            $0.accountClient.fetchAll = { [Self.bankAccount] }
            $0.accountClient.computeBalance = { _ in 5000 }
        }

        await store.send(.alert(.presented(.deleteConfirmed(id)))) {
            $0.alert = nil
        }

        await store.receive(\.accountsLoaded) {
            $0.isLoading = false
            $0.accounts = [Self.bankAccount]
        }

        await store.receive(\.balancesLoaded) {
            $0.balances = [Self.bankAccount.id: 5000]
        }

        #expect(deletedId.value == id)
    }

    // MARK: - Full Archive Confirmation Chain (P1-C)

    @Test("archiveConfirmed calls accountClient.archive and reloads accounts")
    func testArchiveConfirmedCallsArchiveAndReloadsAccounts() async throws {
        let archivedId: LockIsolated<Account.ID?> = LockIsolated(nil)
        let id = Self.cashAccount.id

        var initialState = AccountManagementFeature.State()
        initialState.accounts = [Self.cashAccount, Self.bankAccount]
        initialState.alert = AlertState {
            TextState(String(localized: "alert_cannot_delete"))
        } actions: {
            ButtonState(action: .archiveConfirmed(id)) {
                TextState(String(localized: "alert_archive_instead"))
            }
            ButtonState(role: .cancel) {
                TextState(String(localized: "common_cancel"))
            }
        } message: {
            TextState(String(localized: "alert_archive_account_message"))
        }

        // After archive, fetchAll returns both — cash now archived
        var archivedCash = Self.cashAccount
        archivedCash.isArchived = true
        let afterArchive: [Account] = [archivedCash, Self.bankAccount]

        let store = await TestStore(initialState: initialState) {
            AccountManagementFeature()
        } withDependencies: {
            $0.accountClient.archive = { archivedId.setValue($0) }
            $0.accountClient.fetchAll = { afterArchive }
            $0.accountClient.computeBalance = { _ in 0 }
        }

        await store.send(.alert(.presented(.archiveConfirmed(id)))) {
            $0.alert = nil
        }

        await store.receive(\.accountsLoaded) {
            $0.isLoading = false
            $0.accounts = afterArchive
        }

        await store.receive(\.balancesLoaded) {
            $0.balances = [Self.cashAccount.id: 0, Self.bankAccount.id: 0]
        }

        #expect(archivedId.value == id)
    }

    // MARK: - Unarchive Flow

    @Test("unarchiveTapped calls update and reloads")
    func testUnarchiveTapped() async throws {
        let calledUpdate: LockIsolated<Account?> = LockIsolated(nil)
        let id = Self.archivedAccount.id
        var initialState = AccountManagementFeature.State()
        initialState.accounts = [Self.archivedAccount]

        let store = await TestStore(initialState: initialState) {
            AccountManagementFeature()
        } withDependencies: {
            $0.accountClient.update = { account in calledUpdate.setValue(account) }
            $0.accountClient.fetchAll = { [Self.cashAccount] }
            $0.accountClient.computeBalance = { _ in 0 }
        }

        await store.send(.unarchiveTapped(id))

        await store.receive(\.accountsLoaded) {
            $0.accounts = [Self.cashAccount]
        }

        await store.receive(\.balancesLoaded) {
            $0.balances = [Self.cashAccount.id: 0]
        }

        #expect(calledUpdate.value?.isArchived == false)
        #expect(calledUpdate.value?.id == id)
    }

    // MARK: - Reorder

    @Test("accountMoved reorders active accounts and updates sortOrder")
    func testAccountMoved() async throws {
        let updatedAccounts: LockIsolated<[Account]> = LockIsolated([])

        var initialState = AccountManagementFeature.State()
        initialState.accounts = [Self.cashAccount, Self.bankAccount]

        let store = await TestStore(initialState: initialState) {
            AccountManagementFeature()
        } withDependencies: {
            $0.accountClient.update = { account in
                updatedAccounts.withValue { $0.append(account) }
            }
        }

        // Move bank (index 1) to position 0
        await store.send(.accountMoved(IndexSet(integer: 1), 0)) {
            var reorderedBank = Self.bankAccount
            reorderedBank.sortOrder = 0
            var reorderedCash = Self.cashAccount
            reorderedCash.sortOrder = 1
            $0.accounts = [reorderedCash, reorderedBank]
        }

        // Verify updates were called
        #expect(updatedAccounts.value.count == 2)
        #expect(updatedAccounts.value.first { $0.id == Self.bankAccount.id }?.sortOrder == 0)
        #expect(updatedAccounts.value.first { $0.id == Self.cashAccount.id }?.sortOrder == 1)
    }
}
