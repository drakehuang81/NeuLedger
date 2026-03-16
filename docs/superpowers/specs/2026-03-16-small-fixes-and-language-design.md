# Small Fixes & Language Preference Design

## Overview

Four targeted improvements: transfer validation, account reordering, default account picker, and language preference (follow system).

---

## 1. Transfer Source ≠ Destination Validation

**Goal:** Prevent users from creating transfers where source and destination accounts are the same.

**Changes:**

- `AddTransactionFeature.State`: Add `transferError: String?`
- `AddTransactionFeature.saveTapped`: When `type == .transfer && accountId == toAccountId`, set `transferError` and block save
- `AddTransactionFeature.toAccountSelected`: Clear `transferError`
- `AddTransactionView`: Display `transferError` inline below the destination account picker
- Localization: Add key `add_transaction_error_same_account`

---

## 2. Account Reordering (Drag-to-Reorder)

**Goal:** Allow users to reorder active accounts via drag gesture, matching the existing category reorder pattern.

**Reference:** `CategoryManagementFeature.categoriesMoved` (lines 95-124)

**Changes:**

- `AccountManagementFeature.Action`: Add `accountMoved(IndexSet, Int)`
- `AccountManagementFeature.body`: On move — reorder the active accounts array, reassign `sortOrder` by index, batch update via `accountClient.update`. Use `CancelID.reorder` with `cancelInFlight: true` for debounce.
- `AccountManagementView`: Add `.onMove` modifier to active accounts `ForEach`. Add `EditButton` in toolbar.

---

## 3. Default Account Picker in Settings

**Goal:** Let users choose which account is pre-selected when adding new transactions.

**Changes:**

### UserSettingsClient (Domain + Core)

- `SettingsKey<String>` extension: Add `defaultAccountId` key (default: `""`)
- `UserSettingsClient`: Add `string(_: SettingsKey<String>) -> String` and `setString(_: String, _: SettingsKey<String>)` methods
- `UserSettingsClient+Live.swift`: Implement with `UserDefaults.standard`
- `UserSettingsClient` testValue: Add unimplemented stubs for string methods

### SettingsFeature

- `State`: Add `accounts: [Account]` and `selectedDefaultAccountId: String`
- `Action`: Add `defaultAccountSelected(Account.ID)`
- `task`: Load `userSettingsClient.string(.defaultAccountId)` and set state
- `defaultAccountSelected`: Call `userSettingsClient.setString(id, .defaultAccountId)`, update `defaultAccountName`
- `accountsLoaded`: Populate `accounts` array

### SettingsView

- Default account row becomes a `Picker` (menu style) displaying account names

### AddTransactionFeature

- `optionsLoaded`: If `mode == .add`, read `userSettingsClient.string(.defaultAccountId)` and use it instead of `accounts.first?.id`

---

## 4. Language Preference (Follow System)

**Goal:** Show current system language, tapping opens iOS Settings for this app.

**Changes:**

- `SettingsFeature.State`: Add `currentLanguage: String` (computed from `Locale.current`)
- `SettingsFeature.Action`: Add `languageTapped`
- `languageTapped`: Open `UIApplication.openSettingsURLString` via a new `\.openURL` or `\.openSettings` dependency
- `SettingsView`: Language row becomes a `Button` showing the current language display name with a chevron

For opening the URL, use `@Dependency(\.openURL)` (TCA provides this).

### Language Display

```swift
let langCode = Locale.current.language.languageCode?.identifier ?? "zh"
let displayName = Locale.current.localizedString(forLanguageCode: langCode) ?? langCode
```

---

## Not In Scope

- CSV/JSON export
- AI features
- Privacy policy link
