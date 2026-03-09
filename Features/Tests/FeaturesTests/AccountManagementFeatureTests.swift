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
            $0.nameError = "請輸入帳戶名稱"
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
            $0.nameError = "此名稱已被使用"
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
                TextState("無法刪除")
            } actions: {
                ButtonState(action: AccountManagementFeature.Action.Alert.archiveConfirmed(id)) {
                    TextState("改為封存")
                }
                ButtonState(role: .cancel) {
                    TextState("取消")
                }
            } message: {
                TextState("此帳戶有關聯交易，無法刪除。是否改為封存？")
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
                TextState("確定要刪除？")
            } actions: {
                ButtonState(role: .destructive, action: AccountManagementFeature.Action.Alert.deleteConfirmed(id)) {
                    TextState("刪除")
                }
                ButtonState(role: .cancel) {
                    TextState("取消")
                }
            } message: {
                TextState("此操作無法還原。")
            }
        }
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
}
