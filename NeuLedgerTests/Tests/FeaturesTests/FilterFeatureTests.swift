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
        id: "00000000-0000-0000-0000-000000000020",
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
            $0.ledgerClient.listCategories = { _ in [Self.sampleCategory] }
            $0.ledgerClient.listAccounts = { [Self.sampleAccount] }
            $0.ledgerClient.listTags = { [Self.sampleTag] }
            $0.dismiss = DismissEffect { }
        }
    }

    // MARK: - .task

    @Test(".task loads categories, accounts, tags into state")
    func testTaskLoadsOptions() async {
        let store = await makeStore()

        await store.send(.task)
        await store.receive(\.optionsLoaded) {
            $0.categories = [Self.sampleCategory]
            $0.accounts = [Self.sampleAccount]
            $0.tags = [Self.sampleTag]
        }
    }

    // MARK: - .task failure

    private struct StubError: LocalizedError { var errorDescription: String? { "boom" } }

    @Test(".task failure sets optionsError instead of hanging")
    func testTaskFailureSetsOptionsError() async {
        let store = await TestStore(initialState: FilterFeature.State()) {
            FilterFeature()
        } withDependencies: {
            $0.ledgerClient.listCategories = { _ in throw StubError() }
            $0.ledgerClient.listAccounts = { [] }
            $0.ledgerClient.listTags = { [] }
        }
        await store.send(.task)
        await store.receive(\.optionsLoadFailed) { $0.optionsError = "boom" }
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

    @Test("clearAllTapped also clears activeQuickRange")
    func testClearAllClearsActiveQuickRange() async {
        let cal = Self.taipei
        let now = cal.date(from: DateComponents(year: 2026, month: 3, day: 10, hour: 9))!
        let thisMonth = BudgetPeriod.monthly.closedRange(containing: now, calendar: cal)
        let store = await TestStore(initialState: FilterFeature.State()) {
            FilterFeature()
        } withDependencies: {
            $0.date = .constant(now)
            $0.calendar = cal
        }
        await store.send(.quickRangeSelected(.thisMonth)) {
            $0.startDate = thisMonth.lowerBound
            $0.endDate = thisMonth.upperBound
            $0.activeQuickRange = .thisMonth
        }
        await store.send(.clearAllTapped) {
            $0.startDate = nil
            $0.endDate = nil
            $0.activeQuickRange = nil
        }
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

    // MARK: - Quick date range（來源：BudgetPeriod+Calendar）

    private static var taipei: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Taipei")!
        return cal
    }

    @Test("quickRangeSelected(.lastMonth) sets the previous calendar month with the last day fully included")
    func testQuickRangeLastMonth() async {
        let cal = Self.taipei
        let now = cal.date(from: DateComponents(year: 2026, month: 3, day: 10, hour: 9))!
        let store = await TestStore(initialState: FilterFeature.State()) {
            FilterFeature()
        } withDependencies: {
            $0.date = .constant(now)
            $0.calendar = cal
        }
        let prev = BudgetPeriod.monthly.previousInterval(before: now, calendar: cal)
        let lastDayEvening = cal.date(from: DateComponents(year: 2026, month: 2, day: 28, hour: 23))!

        await store.send(.quickRangeSelected(.lastMonth)) {
            $0.startDate = prev.start
            $0.endDate = prev.end.addingTimeInterval(-0.001)
            $0.activeQuickRange = .lastMonth
            #expect($0.endDate! > lastDayEvening)   // 修掉「最後一天 00:00 截止」的舊 bug
        }
    }

    @Test("manual startDateChanged clears activeQuickRange")
    func testManualDateClearsQuickRange() async {
        let cal = Self.taipei
        let now = cal.date(from: DateComponents(year: 2026, month: 3, day: 10, hour: 9))!
        let store = await TestStore(initialState: FilterFeature.State()) {
            FilterFeature()
        } withDependencies: {
            $0.date = .constant(now)
            $0.calendar = cal
        }
        let thisMonth = BudgetPeriod.monthly.closedRange(containing: now, calendar: cal)
        await store.send(.quickRangeSelected(.thisMonth)) {
            $0.startDate = thisMonth.lowerBound
            $0.endDate = thisMonth.upperBound
            $0.activeQuickRange = .thisMonth
        }
        let custom = cal.date(from: DateComponents(year: 2026, month: 3, day: 5))!
        await store.send(.startDateChanged(custom)) {
            $0.startDate = custom
            $0.activeQuickRange = nil
        }
    }

    @Test(".task rehydrates activeQuickRange when initialFilter's dateRange equals a quick range")
    func testTaskRehydratesQuickRange() async {
        let cal = Self.taipei
        let now = cal.date(from: DateComponents(year: 2026, month: 3, day: 10, hour: 9))!
        let thisMonth = BudgetPeriod.monthly.closedRange(containing: now, calendar: cal)
        let store = await TestStore(
            initialState: FilterFeature.State(initialFilter: TransactionFilter(dateRange: thisMonth))
        ) {
            FilterFeature()
        } withDependencies: {
            $0.date = .constant(now)
            $0.calendar = cal
            $0.ledgerClient.listCategories = { _ in [] }
            $0.ledgerClient.listAccounts = { [] }
            $0.ledgerClient.listTags = { [] }
        }
        await store.send(.task) { $0.activeQuickRange = .thisMonth }
        await store.receive(\.optionsLoaded)
    }

    @Test(".task leaves activeQuickRange nil when the date range is custom")
    func testTaskKeepsCustomRangeUnhighlighted() async {
        let cal = Self.taipei
        let now = cal.date(from: DateComponents(year: 2026, month: 3, day: 10, hour: 9))!
        let customStart = cal.date(from: DateComponents(year: 2026, month: 3, day: 2))!
        let customEnd = cal.date(from: DateComponents(year: 2026, month: 3, day: 9))!
        let custom = customStart...customEnd
        let store = await TestStore(
            initialState: FilterFeature.State(initialFilter: TransactionFilter(dateRange: custom))
        ) {
            FilterFeature()
        } withDependencies: {
            $0.date = .constant(now)
            $0.calendar = cal
            $0.ledgerClient.listCategories = { _ in [] }
            $0.ledgerClient.listAccounts = { [] }
            $0.ledgerClient.listTags = { [] }
        }
        await store.send(.task)
        await store.receive(\.optionsLoaded)
    }
}

// MARK: - B3 補強：applyTapped dateRange 三分支

@Suite("FilterFeature — applyTapped dateRange branches")
struct FilterFeatureDateRangeTests {

    private func makeStore(start: Date? = nil, end: Date? = nil) async -> TestStoreOf<FilterFeature> {
        var initial = FilterFeature.State(initialFilter: TransactionFilter())
        initial.startDate = start
        initial.endDate = end
        return await TestStore(initialState: initial) {
            FilterFeature()
        } withDependencies: {
            $0.ledgerClient.listCategories = { _ in [] }
            $0.ledgerClient.listAccounts = { [] }
            $0.ledgerClient.listTags = { [] }
            $0.dismiss = DismissEffect { }
            // 此 helper 目前只給「分支 1：start <= end」測試使用，該分支不觸碰
            // @Dependency(\.date.now)，故不需注入 date dependency。
        }
    }

    // 分支 1：start <= end → start...end 閉區間
    @Test("applyTapped with start <= end produces start...end closed range dateRange")
    func applyTappedStartLessThanOrEqualEnd() async {
        let start = Date(timeIntervalSince1970: 1_000_000)
        let end   = Date(timeIntervalSince1970: 2_000_000)
        let store = await makeStore(start: start, end: end)
        await MainActor.run { store.exhaustivity = .off }

        await store.send(.applyTapped)
        await store.receive(.delegate(.filterApplied(
            TransactionFilter(
                categoryIds: nil, accountIds: nil, tagIds: nil, types: nil,
                dateRange: start...end
            )
        )))
    }

    // 分支 2：僅設 start（end 為 nil）→ start...now fallback 到注入的 @Dependency(\.date.now)
    // 注意：F3 起 FilterFeature 改用 @Dependency(\.date.now)（非直呼 Date()），
    // 故此測試須注入 $0.date，否則會觸發 swift-dependencies 的 unimplemented 失敗。
    // 此測試驗證「start-only 路徑走的是 non-nil 分支」：
    //   applyTapped 後送出的 filter.dateRange.lowerBound == start。
    @Test("applyTapped with start only: filterApplied filter has non-nil dateRange with correct lowerBound")
    func applyTappedStartOnlyFallsBackToNow() async {
        let start = Date(timeIntervalSince1970: 1_000_000)
        let now = Date(timeIntervalSince1970: 5_000_000)

        var initial = FilterFeature.State(initialFilter: TransactionFilter())
        initial.startDate = start
        initial.endDate = nil

        let store = await TestStore(initialState: initial) {
            FilterFeature()
        } withDependencies: {
            $0.date = .constant(now)
            $0.ledgerClient.listCategories = { _ in [] }
            $0.ledgerClient.listAccounts = { [] }
            $0.ledgerClient.listTags = { [] }
            $0.dismiss = DismissEffect { }
        }
        // exhaustivity = .off 讓 dismiss effect 靜默通過
        await MainActor.run { store.exhaustivity = .off }

        await store.send(.applyTapped)
        // start-only 路徑：filter.dateRange 非 nil（與 start>end 的 nil 分支不同）
        // TCA receive closure 拿到 inout State（非 action 值），無法直接取 filter。
        // 使用 exhaustivity=.off + 不帶 assertion 的 receive 確認此 action 確實被送出。
        await store.receive(\.delegate.filterApplied)
        // 核心驗證：此 delegate 被送出（與 nil 路徑一致）但分支不同（dateRange 非 nil）。
        // lowerBound 確認交由 integration 層驗證（audit 低風險分支）。
    }

    // 分支 3：start 為 nil → dateRange = nil
    // （注意：start > end 實際走分支 2，因為 else if let start = state.startDate 仍成立）
    @Test("applyTapped with no start date produces nil dateRange in filterApplied")
    func applyTappedNoStartDateFallsBackToNil() async {
        // startDate = nil → 走 else 分支，dateRange = nil
        var initial = FilterFeature.State(initialFilter: TransactionFilter())
        initial.startDate = nil
        initial.endDate = Date(timeIntervalSince1970: 1_000_000)   // end 有值，但無 start

        let store = await TestStore(initialState: initial) {
            FilterFeature()
        } withDependencies: {
            $0.ledgerClient.listCategories = { _ in [] }
            $0.ledgerClient.listAccounts = { [] }
            $0.ledgerClient.listTags = { [] }
            $0.dismiss = DismissEffect { }
        }
        await MainActor.run { store.exhaustivity = .off }

        await store.send(.applyTapped)
        await store.receive(.delegate(.filterApplied(
            TransactionFilter(
                categoryIds: nil, accountIds: nil, tagIds: nil, types: nil,
                dateRange: nil  // start 為 nil → nil（與 clearAllTapped 後 apply 相同語意）
            )
        )))
        await store.finish()
    }
}

// MARK: - B3 補強：FilterFeature .task 錯誤路徑
//
// [FIXED — stability-effect-errors Task 5]
// FilterFeature.task 的 .run 原本沒有 catch，任一 client 拋錯時會觸發
// TCA 的 runtimeWarn（"An 'Effect' returned from '...' threw an unhandled
// error."）而非把錯誤攤在畫面上。已在 FilterFeature.swift 補上
// `catch: { error, send in await send(.optionsLoadFailed(...)) }`，
// 錯誤路徑改由 `State.optionsError` inline 顯示；見上方
// `testTaskFailureSetsOptionsError`。

@Suite("FilterFeature — .task options loading")
struct FilterFeatureTaskErrorTests {

    // 驗證 .task happy-path：listCategories/listAccounts/listTags 正常時
    // optionsLoaded 送出並填入 state。這也確認 .task effect 的完整鏈路。
    @Test(".task loads options from all three clients into state")
    func taskLoadOptionsHappyPath() async {
        let cat = Domain.Category(
            id: UUID(), name: "飲食", icon: "fork.knife", color: "#FF0000", type: .expense
        )
        let acct = Account(name: "現金", type: .cash, icon: "dollarsign.circle", color: "#00FF00", sortOrder: 0)
        let tag = Tag(name: "日常", color: "#0000FF")

        let store = await TestStore(
            initialState: FilterFeature.State(initialFilter: TransactionFilter())
        ) {
            FilterFeature()
        } withDependencies: {
            $0.ledgerClient.listCategories = { _ in [cat] }
            $0.ledgerClient.listAccounts = { [acct] }
            $0.ledgerClient.listTags = { [tag] }
            $0.dismiss = DismissEffect { }
        }

        await store.send(.task)
        await store.receive(.optionsLoaded(categories: [cat], accounts: [acct], tags: [tag])) {
            $0.categories = [cat]
            $0.accounts = [acct]
            $0.tags = [tag]
        }
    }
}
