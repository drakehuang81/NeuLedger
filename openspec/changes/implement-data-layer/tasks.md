## 1. Core Package Scaffolding

- [x] 1.1 Create `Core/` directory at the project root with a Swift Package (`Package.swift`) targeting iOS 17+, depending on `Domain` (local) and `SwiftData`
- [x] 1.2 Add `Core` as a local package dependency in the main `NeuLedger.xcodeproj` target
- [x] 1.3 Create directory structure: `Sources/Core/Persistence/Models/`, `Sources/Core/Mappers/`, `Sources/Core/Clients/`, `Sources/Core/Seeding/`, and `Tests/CoreTests/`
- [x] 1.4 Verify the project builds successfully with the empty `Core` module

## 2. SwiftData Model Definitions

- [x] 2.1 Create `SDAccount.swift` — `@Model` class with properties: `id`, `name`, `type` (String), `icon`, `color`, `sortOrder`, `isArchived`, `createdAt`
- [x] 2.2 Create `SDCategory.swift` — `@Model` class with properties: `id`, `name`, `icon`, `color`, `type` (String), `sortOrder`, `isDefault`
- [x] 2.3 Create `SDTag.swift` — `@Model` class with properties: `id`, `name`, `color`; include `@Relationship(inverse: \SDTransaction.tags) var transactions: [SDTransaction]`
- [x] 2.4 Create `SDTransaction.swift` — `@Model` class with properties: `id`, `amount`, `date`, `note`, `categoryId`, `accountId`, `toAccountId`, `type` (String), `aiSuggested`, `createdAt`, `updatedAt`; include `@Relationship var tags: [SDTag]`
- [x] 2.5 Create `SDBudget.swift` — `@Model` class with properties: `id`, `name`, `amount`, `categoryId`, `period` (String), `startDate`, `isActive`
- [x] 2.6 Verify all 5 `@Model` classes compile and SwiftData relationships are valid

## 3. DatabaseClient Dependency

- [x] 3.1 Create `DatabaseClient.swift` — define `@DependencyClient` struct exposing `modelContainer: @Sendable () -> ModelContainer`
- [x] 3.2 Implement `DatabaseClient` `liveValue` with on-disk `ModelContainer` registering all 5 `@Model` types
- [x] 3.3 Implement `DatabaseClient` `testValue` with `ModelConfiguration(isStoredInMemoryOnly: true)`
- [x] 3.4 Register `DatabaseClient` in `DependencyValues` extension

## 4. Domain ↔ SwiftData Mappers

- [x] 4.1 Create `SDAccount+Mapping.swift` — `toDomain() -> Account` and `static func from(_ domain: Account, context: ModelContext) -> SDAccount`
- [x] 4.2 Create `SDCategory+Mapping.swift` — `toDomain() -> Category` and `static func from(_ domain: Category, context: ModelContext) -> SDCategory`
- [x] 4.3 Create `SDTag+Mapping.swift` — `toDomain() -> Tag` and `static func from(_ domain: Tag, context: ModelContext) -> SDTag`
- [x] 4.4 Create `SDTransaction+Mapping.swift` — `toDomain() -> Transaction` (mapping tags array) and `static func from(_ domain: Transaction, context: ModelContext) -> SDTransaction` (resolving existing SDTag by id)
- [x] 4.5 Create `SDBudget+Mapping.swift` — `toDomain() -> Budget` and `static func from(_ domain: Budget, context: ModelContext) -> SDBudget`
- [x] 4.6 Write unit tests for all mappers verifying round-trip conversion (Domain → SD → Domain)

## 5. Live Client Implementations

- [x] 5.1 Create `AccountClient+Live.swift` — implement `fetchAll`, `fetchActive`, `computeBalance`, `add`, `update`, `archive`, `delete` using `@ModelActor`
- [x] 5.2 Create `CategoryClient+Live.swift` — implement `fetchAll`, `fetch(type:)`, `add`, `update`, `delete` (with `isDefault` guard) using `@ModelActor`
- [x] 5.3 Create `TagClient+Live.swift` — implement `fetchAll`, `add`, `update`, `delete` (with auto-disassociation) using `@ModelActor`
- [x] 5.4 Create `TransactionClient+Live.swift` — implement `fetchRecent` (limit 20), `fetchAll`, `fetch(filter:)` (applying all filter criteria), `search`, `add`, `update`, `delete` using `@ModelActor`
- [x] 5.5 Create `BudgetClient+Live.swift` — implement `fetchAll`, `fetchActive`, `add`, `update`, `delete` using `@ModelActor`
- [x] 5.6 Create `AIServiceClient+Live.swift` — implement placeholder `.liveValue` returning empty/default values for all methods
- [x] 5.7 Register all 6 clients as `DependencyKey` conformances with `.liveValue`

## 6. Default Data Seeding

- [x] 6.1 Create `DefaultDataSeeder.swift` with a method that accepts a `ModelContext`
- [x] 6.2 Implement first-launch detection: check if `SDCategory` count is zero
- [x] 6.3 Implement seeding of 9 default expense categories (Food, Transport, Entertainment, Shopping, Housing, Utilities, Health, Education, Other Expense) with specified icons and colors
- [x] 6.4 Implement seeding of 5 default income categories (Salary, Freelance, Investment, Gift, Other Income) with specified icons and colors
- [x] 6.5 Implement seeding of 1 default Cash account
- [x] 6.6 Ensure all seed inserts happen in a single `ModelContext.save()` for atomicity
- [x] 6.7 Integrate seeding into `DatabaseClient` initialization so it runs before any client query

## 7. App Integration

- [x] 7.1 Update `NeuLedgerApp.swift` to `import Core` and attach the live `ModelContainer`
- [x] 7.2 Verify `@Dependency(\.transactionClient)` resolves to the live SwiftData-backed implementation at runtime
- [x] 7.3 Verify default categories and cash account appear in the database after first launch

## 8. Testing & Validation

- [x] 8.1 Write integration tests for `TransactionClient+Live` (add, fetchAll, fetch with filter, update, delete)
- [x] 8.2 Write integration tests for `AccountClient+Live` (add, fetchActive, computeBalance with income/expense/transfer)
- [x] 8.3 Write integration tests for `CategoryClient+Live` (add, fetch by type, delete default guard)
- [x] 8.4 Write integration tests for `DefaultDataSeeder` (verify 14 categories + 1 account seeded, verify idempotency)
- [x] 8.5 Run full project build to confirm `Domain`, `Core`, `Features`, and `NeuLedger` all compile without errors
