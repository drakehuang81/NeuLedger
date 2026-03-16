# Small Fixes & Language Preference Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix four gaps — transfer validation, account reordering, default account picker, and language preference (follow system).

**Architecture:** All changes follow the existing Clean Architecture + TCA pattern. Tasks 1-2 are isolated feature fixes. Tasks 3-4 require extending `UserSettingsClient` with `String` key support first, then updating `SettingsFeature`.

**Tech Stack:** Swift, TCA v1.23.1, SwiftUI, SwiftData (indirect via clients), Swift Testing

**Spec:** `docs/superpowers/specs/2026-03-16-small-fixes-and-language-design.md`

---

## Chunk 1: Transfer Validation & Account Reordering

### Task 1: Transfer Source ≠ Destination Validation

**Files:**
- Modify: `Features/Sources/Features/Dashboard/AddTransactionFeature.swift`
- Modify: `Features/Sources/Features/Dashboard/AddTransactionView.swift`
- Modify: `NeuLedger/Resources/Localizable.xcstrings`

- [ ] **Step 1: Add `transferError` to State and clear it on selection**

In `Features/Sources/Features/Dashboard/AddTransactionFeature.swift`:

Add to State (after line 34, after `categoryError`):
```swift
public var transferError: String?
```

In the `.accountSelected` case (line 143-145), add clearing:
```swift
case let .accountSelected(id):
    state.accountId = id
    state.accountError = nil
    state.transferError = nil
    return .none
```

In the `.toAccountSelected` case (line 148-150), add clearing:
```swift
case let .toAccountSelected(id):
    state.toAccountId = id
    state.transferError = nil
    return .none
```

- [ ] **Step 2: Add validation in `.saveTapped`**

In `Features/Sources/Features/Dashboard/AddTransactionFeature.swift`, in the `.saveTapped` case, after the category validation block (after line 183) and before the `if hasError { return .none }` line:

```swift
if state.type == .transfer && state.accountId != nil && state.accountId == state.toAccountId {
    state.transferError = String(localized: "add_transaction_error_same_account")
    hasError = true
}
```

- [ ] **Step 3: Add inline error display in View**

In `Features/Sources/Features/Dashboard/AddTransactionView.swift`, after the destination account `Picker` (after line 79, inside the transfer branch), add:

```swift
if let error = store.transferError {
    Text(error)
        .font(Font.Design.caption)
        .foregroundStyle(Color.Design.expenseRed)
}
```

- [ ] **Step 4: Add localization key**

In `NeuLedger/Resources/Localizable.xcstrings`, add the key `add_transaction_error_same_account` with:
- zh-Hant: `"來源與目標帳戶不能相同"`
- en: `"Source and destination accounts cannot be the same"`

- [ ] **Step 5: Write test for transfer validation**

There is no existing `AddTransactionFeatureTests` file, so create `Features/Tests/FeaturesTests/AddTransactionFeatureTests.swift`:

```swift
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
        } withDependencies: {
            $0.userSettingsClient.string = { _ in "" }
        }

        await store.send(.saveTapped) {
            $0.transferError = "來源與目標帳戶不能相同"
        }
    }

    @Test("saveTapped with different source and destination clears transferError")
    func testTransferDifferentAccountsNoError() async throws {
        var state = AddTransactionFeature.State(mode: .add(.transfer))
        state.amountText = "100"
        state.accountId = Self.account1.id
        state.toAccountId = Self.account2.id

        let store = await TestStore(initialState: state) {
            AddTransactionFeature()
        } withDependencies: {
            $0.transactionClient.add = { _ in }
            $0.userSettingsClient.string = { _ in "" }
        }

        await store.send(.saveTapped)
        await store.receive(\.savedSuccessfully)
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
}
```

- [ ] **Step 6: Build to verify compilation**

Run:
```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 16' | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 7: Run transfer validation tests**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:FeaturesTests/AddTransactionFeatureTests | tail -10
```
Expected: All tests pass.

- [ ] **Step 8: Commit**

```bash
git add Features/Sources/Features/Dashboard/AddTransactionFeature.swift \
      Features/Sources/Features/Dashboard/AddTransactionView.swift \
      Features/Tests/FeaturesTests/AddTransactionFeatureTests.swift \
      NeuLedger/Resources/Localizable.xcstrings
git commit -m "fix: add transfer source ≠ destination validation in AddTransaction"
```

---

### Task 2: Account Drag-to-Reorder

**Files:**
- Modify: `Features/Sources/Features/AccountManagement/AccountManagementFeature.swift`
- Modify: `Features/Sources/Features/AccountManagement/AccountManagementView.swift`
- Create: (no new files)

- [ ] **Step 1: Add `accountMoved` action and `CancelID.reorder`**

In `Features/Sources/Features/AccountManagement/AccountManagementFeature.swift`:

Add action case (after line 39, after `unarchiveTapped`):
```swift
case accountMoved(IndexSet, Int)
```

Update `CancelID` enum (line 58) to:
```swift
private enum CancelID {
    case task
    case reorder
}
```

- [ ] **Step 2: Implement reorder reducer logic**

In the `body` reducer, add a new case before the `.addEdit` delegate handling (before line 204). Model this after `CategoryManagementFeature.categoriesMoved` (lines 95-124):

```swift
case let .accountMoved(source, destination):
    var active = state.activeAccounts
    active.move(fromOffsets: source, toOffset: destination)

    let reordered = active.enumerated().map { index, account in
        Account(
            id: account.id,
            name: account.name,
            type: account.type,
            icon: account.icon,
            color: account.color,
            sortOrder: index,
            isArchived: account.isArchived,
            createdAt: account.createdAt
        )
    }

    for updated in reordered {
        if let idx = state.accounts.firstIndex(where: { $0.id == updated.id }) {
            state.accounts[idx] = updated
        }
    }

    return .run { _ in
        for account in reordered {
            try await accountClient.update(account)
        }
    }
    .cancellable(id: CancelID.reorder, cancelInFlight: true)
```

- [ ] **Step 3: Add `.onMove` and `EditButton` to View**

In `Features/Sources/Features/AccountManagement/AccountManagementView.swift`:

Add `.onMove` to the active accounts `ForEach` (after the `.onDelete` block, line 70):
```swift
.onMove { from, to in
    store.send(.accountMoved(from, to))
}
```

Add `EditButton` in the toolbar (after the existing `ToolbarItem`, line 42):
```swift
ToolbarItem(placement: .topBarLeading) {
    EditButton()
}
```

- [ ] **Step 4: Write test for reorder**

In `Features/Tests/FeaturesTests/AccountManagementFeatureTests.swift`, add at the end of the suite (before the closing `}`):

```swift
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
```

- [ ] **Step 5: Run tests**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:FeaturesTests/AccountManagementFeatureTests | tail -10
```
Expected: All tests pass.

- [ ] **Step 6: Commit**

```bash
git add Features/Sources/Features/AccountManagement/AccountManagementFeature.swift \
      Features/Sources/Features/AccountManagement/AccountManagementView.swift \
      Features/Tests/FeaturesTests/AccountManagementFeatureTests.swift
git commit -m "feat: add drag-to-reorder for accounts in AccountManagement"
```

---

## Chunk 2: Default Account Picker & Language Preference

### Task 3: Extend UserSettingsClient with String Support

**Files:**
- Modify: `Features/Sources/Domain/Clients/UserSettingsClient.swift`
- Modify: `Features/Sources/Core/Clients/UserSettingsClient+Live.swift`

- [ ] **Step 1: Add String key and client methods**

In `Features/Sources/Domain/Clients/UserSettingsClient.swift`:

After the Bool keys section (after line 45), add:
```swift
// MARK: - String Keys

public extension SettingsKey where Value == String {
    /// The ID of the user's preferred default account for new transactions.
    static let defaultAccountId = SettingsKey(
        rawValue: "defaultAccountId",
        defaultValue: ""
    )
}
```

In the `UserSettingsClient` struct (after `setBool`, line 65), add:
```swift
/// Reads a String value for the given key, returning `defaultValue` if unset.
public var string: @Sendable (_ key: SettingsKey<String>) -> String = { $0.defaultValue }

/// Writes a String value for the given key.
public var setString: @Sendable (_ value: String, _ key: SettingsKey<String>) -> Void
```

Update `testValue` (line 71-74) to:
```swift
public static let testValue = Self(
    bool: { $0.defaultValue },
    setBool: { _, _ in },
    string: { $0.defaultValue },
    setString: { _, _ in }
)
```

- [ ] **Step 2: Implement live String methods**

In `Features/Sources/Core/Clients/UserSettingsClient+Live.swift`, add `string` and `setString` to the `UserSettingsClient` initializer (after `setBool`):

```swift
string: { key in
    UserDefaults.standard.string(forKey: key.rawValue) ?? key.defaultValue
},
setString: { value, key in
    UserDefaults.standard.set(value, forKey: key.rawValue)
}
```

- [ ] **Step 3: Build to verify compilation**

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 16' | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add Features/Sources/Domain/Clients/UserSettingsClient.swift \
      Features/Sources/Core/Clients/UserSettingsClient+Live.swift
git commit -m "feat: add String key support to UserSettingsClient"
```

---

### Task 4: Default Account Picker in Settings

**Files:**
- Modify: `Features/Sources/Features/Settings/SettingsFeature.swift`
- Modify: `Features/Sources/Features/Settings/SettingsView.swift`
- Modify: `Features/Tests/FeaturesTests/SettingsFeatureTests.swift`
- Modify: `Features/Sources/Features/Dashboard/AddTransactionFeature.swift`

- [ ] **Step 1: Update SettingsFeature State and Actions**

In `Features/Sources/Features/Settings/SettingsFeature.swift`:

Update State to:
```swift
@ObservableState
public struct State: Equatable {
    public var isAIEnabled: Bool = true
    public var accounts: [Account] = []
    public var selectedDefaultAccountId: String = ""
    public var defaultAccountName: String = ""

    public init(
        isAIEnabled: Bool = true,
        accounts: [Account] = [],
        selectedDefaultAccountId: String = "",
        defaultAccountName: String = ""
    ) {
        self.isAIEnabled = isAIEnabled
        self.accounts = accounts
        self.selectedDefaultAccountId = selectedDefaultAccountId
        self.defaultAccountName = defaultAccountName
    }
}
```

Add action:
```swift
case defaultAccountSelected(String)
```

- [ ] **Step 2: Update SettingsFeature reducer**

Update the `.task` case to also load the default account ID:
```swift
case .task:
    return .run { send in
        async let accounts = accountClient.fetchActive()
        let isAIEnabled = userSettingsClient.bool(.aiEnabled)
        let defaultId = userSettingsClient.string(.defaultAccountId)
        let fetched = try await accounts
        await send(.accountsLoaded(fetched))
        await send(.aiToggleChanged(isAIEnabled))
        await send(.defaultAccountSelected(defaultId))
    }
    .cancellable(id: CancelID.task)
```

Update `.accountsLoaded` to store accounts and derive the display name from the selected ID:
```swift
case let .accountsLoaded(accounts):
    state.accounts = accounts
    if let selected = accounts.first(where: { $0.id.uuidString == state.selectedDefaultAccountId }) {
        state.defaultAccountName = selected.name
    } else {
        state.defaultAccountName = accounts.first?.name ?? String(localized: "settings_none")
    }
    return .none
```

Add the `defaultAccountSelected` case:
```swift
case let .defaultAccountSelected(id):
    state.selectedDefaultAccountId = id
    userSettingsClient.setString(id, .defaultAccountId)
    if let account = state.accounts.first(where: { $0.id.uuidString == id }) {
        state.defaultAccountName = account.name
    }
    return .none
```

- [ ] **Step 3: Update SettingsView with Picker**

In `Features/Sources/Features/Settings/SettingsView.swift`, replace the default account row in `sectionPreferences` (lines 129-136) with:

```swift
Picker(selection: Binding(
    get: { store.selectedDefaultAccountId },
    set: { store.send(.defaultAccountSelected($0)) }
), label: settingsRow(
    icon: "creditcard",
    iconColor: Color.Design.textSecondary,
    label: String(localized: "settings_default_account"),
    trailing: EmptyView()
)) {
    ForEach(store.accounts) { account in
        Text(account.name).tag(account.id.uuidString)
    }
}
```

- [ ] **Step 4: Update AddTransactionFeature to respect default account**

In `Features/Sources/Features/Dashboard/AddTransactionFeature.swift`:

Add dependency (after line 104):
```swift
@Dependency(\.userSettingsClient) var userSettingsClient
```

Update the `.optionsLoaded` case (lines 124-131). Replace the default account selection logic:
```swift
case let .optionsLoaded(accounts, categories):
    state.isLoading = false
    state.accounts = accounts
    state.categories = categories
    if case .add = state.mode, state.accountId == nil {
        let defaultId = userSettingsClient.string(.defaultAccountId)
        if !defaultId.isEmpty,
           let match = accounts.first(where: { $0.id.uuidString == defaultId }) {
            state.accountId = match.id
        } else {
            state.accountId = accounts.first?.id
        }
    }
    return .none
```

- [ ] **Step 5: Update SettingsFeature tests**

In `Features/Tests/FeaturesTests/SettingsFeatureTests.swift`, update ALL existing tests to account for new state fields (`accounts`) and the new `defaultAccountSelected` action received in `.task`.

Update `testTaskLoadsAIStateAndAccountName`:
```swift
@Test(".task loads AI state, accounts, and default account")
func testTaskLoadsAIStateAndAccountName() async throws {
    let store = await TestStore(
        initialState: SettingsFeature.State()
    ) {
        SettingsFeature()
    } withDependencies: {
        $0.userSettingsClient.bool = { _ in false }
        $0.userSettingsClient.string = { _ in "" }
        $0.accountClient.fetchActive = { Self.sampleAccounts }
    }

    await store.send(.task)

    await store.receive(\.accountsLoaded) {
        $0.accounts = Self.sampleAccounts
        $0.defaultAccountName = "現金錢包"
    }

    await store.receive(\.aiToggleChanged) {
        $0.isAIEnabled = false
    }

    await store.receive(\.defaultAccountSelected)
}
```

Update `testTaskShowsNoneWhenNoAccounts` to receive the new `defaultAccountSelected` action:
```swift
@Test(".task shows '無' when no active accounts")
func testTaskShowsNoneWhenNoAccounts() async throws {
    let store = await TestStore(
        initialState: SettingsFeature.State()
    ) {
        SettingsFeature()
    } withDependencies: {
        $0.userSettingsClient.bool = { _ in true }
        $0.userSettingsClient.string = { _ in "" }
        $0.accountClient.fetchActive = { [] }
    }

    await store.send(.task)

    await store.receive(\.accountsLoaded) {
        $0.defaultAccountName = "無"
    }

    // aiEnabled is already true (default), so no state mutation expected
    await store.receive(\.aiToggleChanged)

    await store.receive(\.defaultAccountSelected)
}
```

Update `testAccountsLoadedSetsFirstAccount` to assert `accounts`:
```swift
@Test("accountsLoaded sets defaultAccountName to first account")
func testAccountsLoadedSetsFirstAccount() async throws {
    let store = await TestStore(
        initialState: SettingsFeature.State()
    ) {
        SettingsFeature()
    }

    await store.send(.accountsLoaded(Self.sampleAccounts)) {
        $0.accounts = Self.sampleAccounts
        $0.defaultAccountName = "現金錢包"
    }
}
```

Update `testAccountsLoadedEmptySetsNone` to assert `accounts`:
```swift
@Test("accountsLoaded with empty array sets defaultAccountName to '無'")
func testAccountsLoadedEmptySetsNone() async throws {
    let store = await TestStore(
        initialState: SettingsFeature.State(defaultAccountName: "現金錢包")
    ) {
        SettingsFeature()
    }

    await store.send(.accountsLoaded([])) {
        $0.defaultAccountName = "無"
    }
}
```

Add a new test for default account selection:
```swift
@Test("defaultAccountSelected persists choice and updates display name")
func testDefaultAccountSelected() async throws {
    let savedValues: LockIsolated<[String]> = LockIsolated([])

    var initialState = SettingsFeature.State()
    initialState.accounts = Self.sampleAccounts

    let store = await TestStore(initialState: initialState) {
        SettingsFeature()
    } withDependencies: {
        $0.userSettingsClient.setString = { value, _ in
            savedValues.withValue { $0.append(value) }
        }
    }

    let targetId = Self.sampleAccounts[1].id.uuidString
    await store.send(.defaultAccountSelected(targetId)) {
        $0.selectedDefaultAccountId = targetId
        $0.defaultAccountName = "銀行帳戶"
    }

    #expect(savedValues.value == [targetId])
}
```

- [ ] **Step 6: Run tests**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:FeaturesTests/SettingsFeatureTests | tail -10
```
Expected: All tests pass.

- [ ] **Step 7: Commit**

```bash
git add Features/Sources/Features/Settings/SettingsFeature.swift \
      Features/Sources/Features/Settings/SettingsView.swift \
      Features/Sources/Features/Dashboard/AddTransactionFeature.swift \
      Features/Tests/FeaturesTests/SettingsFeatureTests.swift
git commit -m "feat: add default account picker in Settings"
```

---

### Task 5: Language Preference (Follow System)

**Files:**
- Modify: `Features/Sources/Features/Settings/SettingsFeature.swift`
- Modify: `Features/Sources/Features/Settings/SettingsView.swift`
- Modify: `Features/Tests/FeaturesTests/SettingsFeatureTests.swift`

- [ ] **Step 1: Add language state and action**

In `Features/Sources/Features/Settings/SettingsFeature.swift`:

Add to State (after `defaultAccountName`):
```swift
public var currentLanguage: String = ""
```

Update `init` to include `currentLanguage`:
```swift
public init(
    isAIEnabled: Bool = true,
    accounts: [Account] = [],
    selectedDefaultAccountId: String = "",
    defaultAccountName: String = "",
    currentLanguage: String = ""
) {
    self.isAIEnabled = isAIEnabled
    self.accounts = accounts
    self.selectedDefaultAccountId = selectedDefaultAccountId
    self.defaultAccountName = defaultAccountName
    self.currentLanguage = currentLanguage
}
```

Add action:
```swift
case languageTapped
```

Add dependency:
```swift
@Dependency(\.openURL) var openURL
```

- [ ] **Step 2: Implement reducer logic**

In the `.task` case, after the existing `await send(...)` calls, add language detection:
```swift
let langCode = Locale.current.language.languageCode?.identifier ?? "zh"
let displayName = Locale.current.localizedString(forLanguageCode: langCode)?.localizedCapitalized ?? langCode
await send(.languageLoaded(displayName))
```

Add a new action case:
```swift
case languageLoaded(String)
```

Add reducer case:
```swift
case let .languageLoaded(name):
    state.currentLanguage = name
    return .none
```

Implement `languageTapped`:
```swift
case .languageTapped:
    return .run { _ in
        if let url = URL(string: UIApplication.openSettingsURLString) {
            await openURL(url)
        }
    }
```

Add `import UIKit` at the top of the file.

- [ ] **Step 3: Update SettingsView**

In `Features/Sources/Features/Settings/SettingsView.swift`, replace the language row (lines 137-143) with:

```swift
Button { store.send(.languageTapped) } label: {
    settingsRow(
        icon: "globe",
        iconColor: Color.Design.textSecondary,
        label: String(localized: "settings_language"),
        trailing: HStack(spacing: 4) {
            Text(store.currentLanguage)
                .font(.body)
                .foregroundStyle(Color.Design.textSecondary)
            chevron
        }
    )
}
```

- [ ] **Step 4: Write test**

In `Features/Tests/FeaturesTests/SettingsFeatureTests.swift`, add `import UIKit` at the top of the file (needed for `UIApplication.openSettingsURLString`), then add:

```swift
@Test("languageTapped opens system settings URL")
func testLanguageTapped() async throws {
    let openedURLs: LockIsolated<[URL]> = LockIsolated([])

    let store = await TestStore(
        initialState: SettingsFeature.State()
    ) {
        SettingsFeature()
    } withDependencies: {
        $0.openURL = .init { url in
            openedURLs.withValue { $0.append(url) }
            return true
        }
    }

    await store.send(.languageTapped)

    #expect(openedURLs.value.count == 1)
    #expect(openedURLs.value.first?.absoluteString == UIApplication.openSettingsURLString)
}
```

- [ ] **Step 5: Run all tests**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:FeaturesTests/SettingsFeatureTests | tail -10
```
Expected: All tests pass.

- [ ] **Step 6: Run full test suite to ensure no regressions**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 16' | tail -10
```
Expected: All tests pass.

- [ ] **Step 7: Commit**

```bash
git add Features/Sources/Features/Settings/SettingsFeature.swift \
      Features/Sources/Features/Settings/SettingsView.swift \
      Features/Tests/FeaturesTests/SettingsFeatureTests.swift
git commit -m "feat: add language preference with system settings link"
```
