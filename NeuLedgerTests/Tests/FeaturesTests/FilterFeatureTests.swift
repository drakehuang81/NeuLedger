import Testing
import Foundation
import ComposableArchitecture
@testable import Features
import Domain

@Suite("FilterFeature Tests")
struct FilterFeatureTests {

    static let sampleCategory = Domain.Category(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000010")!,
        name: "食費", icon: "fork.knife", color: "#FF9500",
        type: .expense, sortOrder: 0, isDefault: false
    )
    static let sampleAccount = Account(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000020")!,
        name: "現金", type: .cash, icon: "banknote", color: "#34C759",
        sortOrder: 0, isArchived: false, createdAt: Date(timeIntervalSince1970: 0)
    )
    static let sampleTag = Tag(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000030")!,
        name: "日常", color: "#FF9500"
    )

    func makeStore() async -> TestStoreOf<FilterFeature> {
        await TestStore(
            initialState: FilterFeature.State(initialFilter: TransactionFilter())
        ) {
            FilterFeature()
        } withDependencies: {
            $0.categoryClient.fetchAll = { [Self.sampleCategory] }
            $0.accountClient.fetchAll = { [Self.sampleAccount] }
            $0.tagClient.fetchAll = { [Self.sampleTag] }
            $0.dismiss = DismissEffect { }
        }
    }

    // MARK: - .task

    @Test(".task loads categories, accounts, tags into state")
    func testTaskLoadsOptions() async {
        let store = await makeStore()

        await store.send(.task) {
            $0.isLoading = true
        }
        await store.receive(\.optionsLoaded) {
            $0.isLoading = false
            $0.categories = [Self.sampleCategory]
            $0.accounts = [Self.sampleAccount]
            $0.tags = [Self.sampleTag]
        }
    }

    // MARK: - Toggle filters

    @Test("typeToggled adds type to selectedTypes")
    func testTypeToggled() async {
        let store = await makeStore()
        await MainActor.run {
            store.exhaustivity = .off
        }

        await store.send(.typeToggled(.expense)) {
            $0.selectedTypes = [.expense]
        }
    }

    @Test("typeToggled twice removes type from selectedTypes")
    func testTypeToggledTwiceRemoves() async {
        let store = await makeStore()
        await MainActor.run {
            store.exhaustivity = .off
        }

        await store.send(.typeToggled(.expense)) { $0.selectedTypes = [.expense] }
        await store.send(.typeToggled(.expense)) { $0.selectedTypes = [] }
    }

    @Test("categoryToggled adds category id to selectedCategoryIds")
    func testCategoryToggled() async {
        let store = await makeStore()
        await MainActor.run {
            store.exhaustivity = .off
        }

        await store.send(.categoryToggled(Self.sampleCategory.id)) {
            $0.selectedCategoryIds = [Self.sampleCategory.id]
        }
    }

    @Test("categoryToggled twice removes category id from selectedCategoryIds")
    func testCategoryToggledTwiceRemoves() async {
        let store = await makeStore()
        await MainActor.run {
            store.exhaustivity = .off
        }

        await store.send(.categoryToggled(Self.sampleCategory.id)) {
            $0.selectedCategoryIds = [Self.sampleCategory.id]
        }
        await store.send(.categoryToggled(Self.sampleCategory.id)) {
            $0.selectedCategoryIds = []
        }
    }

    @Test("accountToggled adds account id to selectedAccountIds")
    func testAccountToggled() async {
        let store = await makeStore()
        await MainActor.run {
            store.exhaustivity = .off
        }

        await store.send(.accountToggled(Self.sampleAccount.id)) {
            $0.selectedAccountIds = [Self.sampleAccount.id]
        }
    }

    @Test("accountToggled twice removes account id from selectedAccountIds")
    func testAccountToggledTwiceRemoves() async {
        let store = await makeStore()
        await MainActor.run {
            store.exhaustivity = .off
        }

        await store.send(.accountToggled(Self.sampleAccount.id)) {
            $0.selectedAccountIds = [Self.sampleAccount.id]
        }
        await store.send(.accountToggled(Self.sampleAccount.id)) {
            $0.selectedAccountIds = []
        }
    }

    @Test("tagToggled adds tag id to selectedTagIds")
    func testTagToggled() async {
        let store = await makeStore()
        await MainActor.run {
            store.exhaustivity = .off
        }

        await store.send(.tagToggled(Self.sampleTag.id)) {
            $0.selectedTagIds = [Self.sampleTag.id]
        }
    }

    @Test("tagToggled twice removes tag id from selectedTagIds")
    func testTagToggledTwiceRemoves() async {
        let store = await makeStore()
        await MainActor.run {
            store.exhaustivity = .off
        }

        await store.send(.tagToggled(Self.sampleTag.id)) {
            $0.selectedTagIds = [Self.sampleTag.id]
        }
        await store.send(.tagToggled(Self.sampleTag.id)) {
            $0.selectedTagIds = []
        }
    }

    // MARK: - Date changes

    @Test("startDateChanged updates startDate in state")
    func testStartDateChanged() async {
        let store = await makeStore()
        await MainActor.run {
            store.exhaustivity = .off
        }

        let date = Date(timeIntervalSince1970: 1_000_000)
        await store.send(.startDateChanged(date)) {
            $0.startDate = date
        }
    }

    @Test("endDateChanged updates endDate in state")
    func testEndDateChanged() async {
        let store = await makeStore()
        await MainActor.run {
            store.exhaustivity = .off
        }

        let date = Date(timeIntervalSince1970: 2_000_000)
        await store.send(.endDateChanged(date)) {
            $0.endDate = date
        }
    }

    // MARK: - Apply

    @Test("applyTapped emits filterApplied delegate with correct filter")
    func testApplyTappedEmitsDelegate() async {
        let store = await makeStore()
        await MainActor.run {
            store.exhaustivity = .off
        }

        await store.send(.typeToggled(.expense)) { $0.selectedTypes = [.expense] }
        await store.send(.applyTapped)
        await store.receive(.delegate(.filterApplied(
            TransactionFilter(
                categoryIds: nil,
                accountIds: nil,
                tagIds: nil,
                types: [.expense],
                dateRange: nil
            )
        )))
    }

    @Test("applyTapped with no selections emits filterApplied with empty filter")
    func testApplyTappedEmptyFilter() async {
        let store = await makeStore()
        await MainActor.run {
            store.exhaustivity = .off
        }

        await store.send(.applyTapped)
        await store.receive(.delegate(.filterApplied(
            TransactionFilter(
                categoryIds: nil,
                accountIds: nil,
                tagIds: nil,
                types: nil,
                dateRange: nil
            )
        )))
    }

    @Test("applyTapped with category selection builds correct filter")
    func testApplyTappedWithCategoryFilter() async {
        let store = await makeStore()
        await MainActor.run {
            store.exhaustivity = .off
        }

        await store.send(.categoryToggled(Self.sampleCategory.id)) {
            $0.selectedCategoryIds = [Self.sampleCategory.id]
        }
        await store.send(.applyTapped)
        await store.receive(.delegate(.filterApplied(
            TransactionFilter(
                categoryIds: [Self.sampleCategory.id],
                accountIds: nil,
                tagIds: nil,
                types: nil,
                dateRange: nil
            )
        )))
    }

    // MARK: - Clear all

    @Test("clearAllTapped resets all filter fields to empty")
    func testClearAllResetsFilters() async {
        let store = await makeStore()
        await MainActor.run {
            store.exhaustivity = .off
        }

        // Set up some selections first
        await store.send(.typeToggled(.expense)) { $0.selectedTypes = [.expense] }
        await store.send(.categoryToggled(Self.sampleCategory.id)) {
            $0.selectedCategoryIds = [Self.sampleCategory.id]
        }
        await store.send(.accountToggled(Self.sampleAccount.id)) {
            $0.selectedAccountIds = [Self.sampleAccount.id]
        }
        await store.send(.tagToggled(Self.sampleTag.id)) {
            $0.selectedTagIds = [Self.sampleTag.id]
        }

        await store.send(.clearAllTapped) {
            $0.selectedTypes = []
            $0.selectedCategoryIds = []
            $0.selectedAccountIds = []
            $0.selectedTagIds = []
            $0.startDate = nil
            $0.endDate = nil
        }
    }

    @Test("clearAllTapped clears date range")
    func testClearAllClearsDateRange() async {
        let start = Date(timeIntervalSince1970: 1_000_000)
        let end = Date(timeIntervalSince1970: 2_000_000)

        let store = await makeStore()
        await MainActor.run {
            store.exhaustivity = .off
        }

        await store.send(.startDateChanged(start)) { $0.startDate = start }
        await store.send(.endDateChanged(end)) { $0.endDate = end }

        await store.send(.clearAllTapped) {
            $0.startDate = nil
            $0.endDate = nil
        }
    }

    // MARK: - Dismiss

    @Test("dismiss action emits dismissed delegate")
    func testDismissEmitsDelegateAction() async {
        let store = await makeStore()
        await MainActor.run {
            store.exhaustivity = .off
        }

        await store.send(.dismiss)
        await store.receive(\.delegate.dismissed)
    }

    // MARK: - hasActiveFilters computed property

    @Test("hasActiveFilters is false when nothing is selected")
    func testHasActiveFiltersFalseInitially() async {
        let state = FilterFeature.State(initialFilter: TransactionFilter())
        #expect(state.hasActiveFilters == false)
    }

    @Test("hasActiveFilters is true when types are selected")
    func testHasActiveFiltersTrueWithTypes() async {
        var state = FilterFeature.State(initialFilter: TransactionFilter())
        state.selectedTypes = [.expense]
        #expect(state.hasActiveFilters == true)
    }

    @Test("initialFilter pre-populates selections from TransactionFilter")
    func testInitialFilterPrePopulates() async {
        let filter = TransactionFilter(
            categoryIds: [Self.sampleCategory.id],
            accountIds: [Self.sampleAccount.id],
            tagIds: [Self.sampleTag.id],
            types: [.income]
        )
        let state = FilterFeature.State(initialFilter: filter)
        #expect(state.selectedTypes == [.income])
        #expect(state.selectedCategoryIds == [Self.sampleCategory.id])
        #expect(state.selectedAccountIds == [Self.sampleAccount.id])
        #expect(state.selectedTagIds == [Self.sampleTag.id])
    }
}
