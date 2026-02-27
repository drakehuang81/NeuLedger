## 1. Entity 協定更新（加上 Hashable）

- [x] 1.1 更新 `Transaction` struct 宣告，加入 `Hashable` 協定（`Sources/Domain/Entities/Transaction.swift`）
- [x] 1.2 更新 `Account` struct 宣告，加入 `Hashable` 協定（`Sources/Domain/Entities/Account.swift`）
- [x] 1.3 更新 `Category` struct 宣告，加入 `Hashable` 協定（`Sources/Domain/Entities/Category.swift`）
- [x] 1.4 更新 `Tag` struct 宣告，加入 `Hashable` 協定（`Sources/Domain/Entities/Tag.swift`）
- [x] 1.5 更新 `Budget` struct 宣告，加入 `Hashable` 協定（`Sources/Domain/Entities/Budget.swift`）

## 2. AI 相關型別新增

- [x] 2.1 建立 `ExtractedTransaction` struct（`Sources/Domain/Entities/ExtractedTransaction.swift`），包含 `amount: Double?`、`suggestedCategory: String?`、`description: String?`、`type: String?`，遵循 `Equatable`, `Sendable`
- [x] 2.2 建立 `CategorySuggestions` struct（`Sources/Domain/Entities/CategorySuggestions.swift`），包含 `suggestions: [String]`、`confidence: String`，遵循 `Equatable`, `Sendable`
- [x] 2.3 建立 `SpendingSummary` struct（`Sources/Domain/Entities/SpendingSummary.swift`），包含 `totalIncome: Decimal`、`totalExpense: Decimal`、`categoryBreakdown: [String: Decimal]`、`periodDescription: String`，遵循 `Equatable`, `Sendable`

## 3. TransactionFilter 型別新增

- [x] 3.1 建立 `TransactionFilter` struct（`Sources/Domain/Entities/TransactionFilter.swift`），包含 `categoryIds: Set<Category.ID>?`、`accountIds: Set<Account.ID>?`、`tagIds: Set<Tag.ID>?`、`types: Set<TransactionType>?`、`dateRange: ClosedRange<Date>?`、`searchText: String?`，遵循 `Equatable`, `Sendable`，所有屬性預設為 `nil`

## 4. AIServiceClient 重寫

- [x] 4.1 移除 `AIServiceClient` 中的 `analyzeReceipt(Data)` 方法
- [x] 4.2 移除 `TransactionParseResult` struct
- [x] 4.3 新增 `extractTransaction: @Sendable (String) async throws -> ExtractedTransaction`
- [x] 4.4 新增 `suggestCategories: @Sendable (String, [String]) async throws -> CategorySuggestions`
- [x] 4.5 新增 `generateInsight: @Sendable (SpendingSummary) async throws -> String`
- [x] 4.6 新增 `isAvailable: @Sendable () -> Bool`（同步方法）
- [x] 4.7 確認 `TestDependencyKey` 和 `DependencyValues` 註冊正確

## 5. TransactionClient 擴充

- [x] 5.1 移除 `fetchByAccount` 和 `fetchByCategory` 方法
- [x] 5.2 新增 `fetch: @Sendable (TransactionFilter) async throws -> [Transaction]`
- [x] 5.3 新增 `search: @Sendable (String) async throws -> [Transaction]`

## 6. AccountClient 擴充

- [x] 6.1 新增 `computeBalance: @Sendable (Account.ID) async throws -> Decimal`

## 7. 新增 TagClient

- [x] 7.1 建立 `TagClient.swift`（`Sources/Domain/Clients/TagClient.swift`），包含 `fetchAll`、`add`、`update`、`delete` 方法
- [x] 7.2 實作 `TestDependencyKey` 和 `DependencyValues` 註冊（key path: `\.tagClient`）

## 8. 新增 BudgetClient

- [x] 8.1 建立 `BudgetClient.swift`（`Sources/Domain/Clients/BudgetClient.swift`），包含 `fetchAll`、`fetchActive`、`add`、`update`、`delete` 方法
- [x] 8.2 實作 `TestDependencyKey` 和 `DependencyValues` 註冊（key path: `\.budgetClient`）

## 9. 編譯驗證

- [x] 9.1 執行 `swift build` 確認所有變更通過編譯

## 10. Enum 單元測試

- [x] 10.1 建立 `TransactionTypeTests.swift` — 驗證 3 個 case、CaseIterable count、Codable round-trip
- [x] 10.2 建立 `AccountTypeTests.swift` — 驗證 4 個 case、CaseIterable count、Codable round-trip
- [x] 10.3 建立 `CurrencyTests.swift` — 驗證 `.TWD` 的 symbol/code/decimalPlaces、Codable round-trip
- [x] 10.4 建立 `BudgetPeriodTests.swift` — 驗證 3 個 case、CaseIterable count、Codable round-trip

## 11. Entity 單元測試

- [x] 11.1 建立 `TransactionTests.swift` — 初始化預設值、自訂值、Equatable、Hashable、Codable round-trip
- [x] 11.2 建立 `AccountTests.swift` — 初始化預設值、自訂值、Equatable、Hashable、Codable round-trip
- [x] 11.3 建立 `CategoryTests.swift` — 初始化預設值、自訂值、Equatable、Hashable、Codable round-trip
- [x] 11.4 建立 `TagTests.swift` — 初始化預設值、自訂值、Equatable、Hashable、Codable round-trip
- [x] 11.5 建立 `BudgetTests.swift` — 初始化預設值、自訂值、Equatable、Hashable、Codable round-trip
- [x] 11.6 建立 `TransactionFilterTests.swift` — 空 filter 預設值、Equatable 測試

## 12. AI 型別單元測試

- [x] 12.1 建立 `ExtractedTransactionTests.swift` — 初始化（全 nil / 全有值）、Equatable
- [x] 12.2 建立 `CategorySuggestionsTests.swift` — 初始化、Equatable
- [x] 12.3 建立 `SpendingSummaryTests.swift` — 初始化、Equatable

## 13. Client 單元測試

- [x] 13.1 建立 `TransactionClientTests.swift` — TestDependencyKey 可用性、DependencyValues key path 存取
- [x] 13.2 建立 `AccountClientTests.swift` — TestDependencyKey 可用性、DependencyValues key path 存取
- [x] 13.3 建立 `CategoryClientTests.swift` — TestDependencyKey 可用性、DependencyValues key path 存取
- [x] 13.4 建立 `TagClientTests.swift` — TestDependencyKey 可用性、DependencyValues key path 存取
- [x] 13.5 建立 `BudgetClientTests.swift` — TestDependencyKey 可用性、DependencyValues key path 存取
- [x] 13.6 建立 `AIServiceClientTests.swift` — TestDependencyKey 可用性、DependencyValues key path 存取

## 14. 測試執行驗證

- [x] 14.1 執行 `swift test` 確認所有測試通過
- [x] 14.2 清理舊的 `Domain.swift` 佔位檔（如仍存在）
