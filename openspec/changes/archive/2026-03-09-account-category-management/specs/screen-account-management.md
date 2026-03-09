# Spec: Screen - Account Management
**Purpose**: Define the Account Management UI list, structure, and editing capabilities.

## Requirements

### Requirement: Account List UI

#### Scenario: Active and Archived Sections
- **WHEN** the user navigates to the Account Management screen
- **THEN** display a grouped list with two possible sections: "Active" and "Archived"
- **AND** display the account's icon, name, type label, and current computed balance (via `accountClient.computeBalance`)
- **AND** balances for all visible accounts SHALL be loaded in parallel using `TaskGroup`
- **AND** the "Archived" section SHALL NOT be shown if there are no archived accounts

#### Scenario: Empty State
- **WHEN** there are no accounts at all (edge case after data wipe)
- **THEN** display an empty state prompting the user to add their first account

### Requirement: CRUD Operations inside UI

#### Scenario: Adding a New Account
- **WHEN** the user taps the "+" or "Add" button
- **THEN** present a sheet containing a form to input:
    - Account Name (Required, validated non-empty and unique)
    - Account Type (Picker from `AccountType.allCases`)
    - Icon (SF Symbol Picker, Optional)
    - Color (Color Picker, Optional)
- **AND** validation errors SHALL be displayed inline (never as Alerts per CLAUDE.md)

#### Scenario: Editing an Existing Account
- **WHEN** the user taps on an existing account in the list
- **THEN** present the edit form (sheet) prepopulated with existing properties
- **AND** allow updating the properties
- **AND** provide "Save" and "Cancel" actions

#### Scenario: Archiving / Deleting an Account
- **WHEN** the user swipes left on an account or selects delete while editing
- **THEN** use `transactionClient.fetch(TransactionFilter(accountIds: [account.id]))` to check for associated transactions
- **AND** if transactions exist, prompt the user with "此帳戶有關聯交易，無法刪除。是否改為封存？"
- **AND** if the user confirms archiving, call `accountClient.archive(account.id)`
- **AND** if NO transactions exist, prompt for permanent deletion confirmation, then call `accountClient.delete(account.id)`

#### Scenario: Unarchiving an Account
- **WHEN** the user taps on an archived account
- **THEN** provide an option to unarchive (restore to active) via `accountClient.update` setting `isArchived = false`
