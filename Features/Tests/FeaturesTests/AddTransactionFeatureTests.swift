import Testing
import Foundation
import ComposableArchitecture
import Domain
@testable import Features

@Suite("AddTransactionFeature Tests")
struct AddTransactionFeatureTests {

    private static let account1 = Account(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        name: "現金", type: .cash, icon: "banknote", color: "#34C759"
    )
    private static let account2 = Account(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        name: "銀行", type: .bank, icon: "building.columns", color: "#3478F6"
    )

    @Test("saveTapped with same source and destination sets transferError")
    func testTransferSameAccountValidation() async throws {
        var state = AddTransactionFeature.State(mode: .add(.transfer))
        state.amountText = "100"
        state.accountId = Self.account1.id
        state.toAccountId = Self.account1.id

        let store = await TestStore(initialState: state) {
            AddTransactionFeature()
        }

        await store.send(.saveTapped) {
            $0.transferError = String(localized: "add_transaction_error_same_account")
        }
    }

    @Test("saveTapped with different source and destination proceeds")
    func testTransferDifferentAccountsNoError() async throws {
        var state = AddTransactionFeature.State(mode: .add(.transfer))
        state.amountText = "100"
        state.accountId = Self.account1.id
        state.toAccountId = Self.account2.id

        let store = await TestStore(initialState: state) {
            AddTransactionFeature()
        } withDependencies: {
            $0.transactionClient.add = { _ in }
        }

        await store.send(.saveTapped)
        await store.receive(\.savedSuccessfully)
        await store.receive(\.delegate.saved)
    }

    @Test("toAccountSelected clears transferError")
    func testToAccountSelectedClearsError() async throws {
        var state = AddTransactionFeature.State(mode: .add(.transfer))
        state.transferError = "來源與目標帳戶不能相同"

        let store = await TestStore(initialState: state) {
            AddTransactionFeature()
        }

        await store.send(.toAccountSelected(Self.account2.id)) {
            $0.toAccountId = Self.account2.id
            $0.transferError = nil
        }
    }

    @Test(".addPrefilled mode pre-fills form fields from ExtractedTransaction")
    func addPrefilledModePreFillsFields() async {
        let extracted = ExtractedTransaction(
            amount: 150,
            suggestedCategory: "食物",
            description: "午餐便當",
            type: "expense"
        )
        let state = AddTransactionFeature.State(mode: .addPrefilled(extracted))
        #expect(state.amountText == "150")
        #expect(state.note == "午餐便當")
        #expect(state.type == .expense)
        #expect(state.categoryId == nil)
    }

    @Test(".addPrefilled with all-nil fields uses sensible defaults")
    func addPrefilledNilFieldsDefaults() async {
        let extracted = ExtractedTransaction()
        let state = AddTransactionFeature.State(mode: .addPrefilled(extracted))
        #expect(state.amountText == "")
        #expect(state.note == "")
        #expect(state.type == .expense)
    }
}
