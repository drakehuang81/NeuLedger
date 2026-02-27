## ADDED Requirements

### Requirement: TransactionClient Live Implementation
`TransactionClient` SHALL have a `.liveValue` conforming to `DependencyKey` backed by SwiftData.

#### Scenario: Fetch Recent Transactions
- **WHEN** `transactionClient.fetchRecent()` is called
- **THEN** it SHALL return up to 20 transactions sorted by `date` descending.

#### Scenario: Fetch All Transactions
- **WHEN** `transactionClient.fetchAll()` is called
- **THEN** it SHALL return all stored transactions sorted by `date` descending.

#### Scenario: Fetch Filtered Transactions
- **WHEN** `transactionClient.fetch(filter)` is called with a `TransactionFilter`
- **THEN** it SHALL apply all non-nil filter criteria (categoryIds, accountIds, tagIds, types, dateRange, searchText).
- **AND** results SHALL be sorted by `date` descending.
- **AND** `searchText` SHALL match against the transaction's `note` field (case-insensitive).

#### Scenario: Search Transactions
- **WHEN** `transactionClient.search(query)` is called
- **THEN** it SHALL return transactions whose `note` contains the query string (case-insensitive).

#### Scenario: Add Transaction
- **WHEN** `transactionClient.add(transaction)` is called
- **THEN** it SHALL map the Domain `Transaction` to `SDTransaction` and insert it into SwiftData.
- **AND** it SHALL resolve tag associations via the mapper.

#### Scenario: Update Transaction
- **WHEN** `transactionClient.update(transaction)` is called
- **THEN** it SHALL find the existing `SDTransaction` by `id`, update all fields, and save.
- **AND** if the transaction is not found, it SHALL throw an error.

#### Scenario: Delete Transaction
- **WHEN** `transactionClient.delete(id)` is called
- **THEN** it SHALL find the `SDTransaction` by `id` and delete it from SwiftData.

---

### Requirement: AccountClient Live Implementation
`AccountClient` SHALL have a `.liveValue` conforming to `DependencyKey` backed by SwiftData.

#### Scenario: Fetch All Accounts
- **WHEN** `accountClient.fetchAll()` is called
- **THEN** it SHALL return all accounts sorted by `sortOrder` ascending.

#### Scenario: Fetch Active Accounts
- **WHEN** `accountClient.fetchActive()` is called
- **THEN** it SHALL return only accounts where `isArchived == false`, sorted by `sortOrder` ascending.

#### Scenario: Compute Account Balance
- **WHEN** `accountClient.computeBalance(accountId)` is called
- **THEN** it SHALL sum all transactions where `accountId` matches and `type == .income`, subtract all where `type == .expense`.
- **AND** for transfer transactions, it SHALL add to the balance if the account is the `toAccountId` and subtract if it is the source `accountId`.

#### Scenario: Add Account
- **WHEN** `accountClient.add(account)` is called
- **THEN** it SHALL map and insert the account into SwiftData.

#### Scenario: Update Account
- **WHEN** `accountClient.update(account)` is called
- **THEN** it SHALL find the existing `SDAccount` by `id`, update all mutable fields, and save.

#### Scenario: Archive Account
- **WHEN** `accountClient.archive(id)` is called
- **THEN** it SHALL set `isArchived = true` on the matching `SDAccount`.

#### Scenario: Delete Account
- **WHEN** `accountClient.delete(id)` is called
- **THEN** it SHALL remove the `SDAccount` from SwiftData.

---

### Requirement: CategoryClient Live Implementation
`CategoryClient` SHALL have a `.liveValue` conforming to `DependencyKey` backed by SwiftData.

#### Scenario: Fetch All Categories
- **WHEN** `categoryClient.fetchAll()` is called
- **THEN** it SHALL return all categories sorted by `sortOrder` ascending.

#### Scenario: Fetch Categories by Type
- **WHEN** `categoryClient.fetch(type)` is called with a `TransactionType`
- **THEN** it SHALL return only categories matching the given type, sorted by `sortOrder` ascending.

#### Scenario: Add Category
- **WHEN** `categoryClient.add(category)` is called
- **THEN** it SHALL map and insert the category into SwiftData.

#### Scenario: Update Category
- **WHEN** `categoryClient.update(category)` is called
- **THEN** it SHALL find the existing `SDCategory` by `id`, update all mutable fields, and save.

#### Scenario: Delete Category
- **WHEN** `categoryClient.delete(id)` is called
- **THEN** it SHALL remove the `SDCategory` from SwiftData.
- **AND** it SHALL NOT allow deletion of categories where `isDefault == true`.

---

### Requirement: BudgetClient Live Implementation
`BudgetClient` SHALL have a `.liveValue` conforming to `DependencyKey` backed by SwiftData.

#### Scenario: Fetch All Budgets
- **WHEN** `budgetClient.fetchAll()` is called
- **THEN** it SHALL return all budgets.

#### Scenario: Fetch Active Budgets
- **WHEN** `budgetClient.fetchActive()` is called
- **THEN** it SHALL return only budgets where `isActive == true`.

#### Scenario: Add Budget
- **WHEN** `budgetClient.add(budget)` is called
- **THEN** it SHALL map and insert the budget into SwiftData.

#### Scenario: Update Budget
- **WHEN** `budgetClient.update(budget)` is called
- **THEN** it SHALL find the existing `SDBudget` by `id`, update all mutable fields, and save.

#### Scenario: Delete Budget
- **WHEN** `budgetClient.delete(id)` is called
- **THEN** it SHALL remove the `SDBudget` from SwiftData.

---

### Requirement: TagClient Live Implementation
`TagClient` SHALL have a `.liveValue` conforming to `DependencyKey` backed by SwiftData.

#### Scenario: Fetch All Tags
- **WHEN** `tagClient.fetchAll()` is called
- **THEN** it SHALL return all tags sorted by `name` ascending.

#### Scenario: Add Tag
- **WHEN** `tagClient.add(tag)` is called
- **THEN** it SHALL map and insert the tag into SwiftData.

#### Scenario: Update Tag
- **WHEN** `tagClient.update(tag)` is called
- **THEN** it SHALL find the existing `SDTag` by `id`, update all mutable fields, and save.

#### Scenario: Delete Tag
- **WHEN** `tagClient.delete(id)` is called
- **THEN** it SHALL remove the `SDTag` from SwiftData.
- **AND** it SHALL automatically disassociate the tag from any linked transactions.

---

### Requirement: AIServiceClient Placeholder Implementation
`AIServiceClient` SHALL have a `.liveValue` that returns placeholder data in this phase.

#### Scenario: Extract Transaction Placeholder
- **WHEN** `aiServiceClient.extractTransaction(text)` is called
- **THEN** it SHALL return an empty `ExtractedTransaction()`.

#### Scenario: Suggest Categories Placeholder
- **WHEN** `aiServiceClient.suggestCategories(description)` is called
- **THEN** it SHALL return a `CategorySuggestions` with an empty `suggestions` array and `confidence` of `"none"`.

#### Scenario: Generate Insights Placeholder
- **WHEN** `aiServiceClient.generateInsights(summary)` is called
- **THEN** it SHALL return an empty string.

#### Scenario: Check Availability Placeholder
- **WHEN** `aiServiceClient.isAvailable()` is called
- **THEN** it SHALL return `false`.
