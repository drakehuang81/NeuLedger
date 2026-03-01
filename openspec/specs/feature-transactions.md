# Spec: Feature - Transactions
**Purpose**: Define the core transaction management logic, including currency rules, transaction creation, editing, deleting, and searching/filtering.

## Requirements

### Requirement: Currency
- **GIVEN** the first version of the app
- **THEN** only **TWD (New Taiwan Dollar)** is supported.
- **AND** all amounts are displayed with the "NT$" prefix and **zero decimal places** (整數).
- **AND** the `Currency` enum is kept in code for future extensibility but only `.TWD` is active.

### Requirement: Core User Stories (記帳)

#### Scenario: 快速新增支出
- **GIVEN** 使用者在 Dashboard 或 Transactions tab
- **WHEN** 點擊「支出」快速操作
- **THEN** 開啟新增交易 Sheet（類型預設為 `.expense`）
- **AND** 金額欄位為必填，預設為空
- **AND** 帳戶預設為使用者設定的預設帳戶
- **AND** 日期預設為今天
- **AND** 分類預設為空（需選擇或由 AI 建議）

#### Scenario: 快速新增支出 (from Dashboard Empty State)
- **GIVEN** 使用者在 Dashboard 且無任何交易
- **WHEN** 點擊 Empty State 的「記一筆」按鈕
- **THEN** 開啟新增交易 Sheet（類型預設為 `.expense`）
- **AND** 金額欄位為必填，預設為空

#### Scenario: 快速新增收入
- **GIVEN** 使用者在 Dashboard 或 Transactions tab
- **WHEN** 點擊「收入」快速操作
- **THEN** 開啟新增交易 Sheet（類型預設為 `.income`）
- **AND** 分類選擇器僅顯示收入類型的分類

#### Scenario: 帳戶間轉帳
- **GIVEN** 使用者在 Dashboard
- **WHEN** 點擊「轉帳」快速操作
- **THEN** 開啟轉帳 Sheet
- **AND** 必須選擇來源帳戶和目標帳戶（不得相同）
- **AND** 轉帳不需要選擇分類
- **AND** 儲存後：來源帳戶餘額減少、目標帳戶餘額增加

#### Scenario: AI 輔助記帳
- **GIVEN** AI 功能可用且使用者已啟用自動分類
- **WHEN** 使用者在備註欄輸入文字（e.g., "午餐 麥當勞 200"）
- **THEN** AI 將自動建議：
    1. **金額**：從文字中提取（若偵測到）→ 自動填入金額欄
    2. **分類**：建議最可能的分類 → 在分類選擇器中高亮顯示
- **AND** 使用者可以接受或覆蓋 AI 建議
- **AND** 若 AI 不可用，備註欄正常運作（無 sparkle 圖示）

### Requirement: 交易管理（Transaction Management）

#### Scenario: 查看交易列表
- **GIVEN** 使用者在 Transactions tab
- **THEN** 顯示所有交易，按日期降序排列（最新在上）
- **AND** 以日期分組顯示（"Today", "Yesterday", "2026/2/10" 等）
- **AND** 每筆交易顯示：分類圖示、備註、金額（支出紅色、收入綠色）、日期

#### Scenario: 搜尋交易
- **WHEN** 使用者在搜尋列輸入文字
- **THEN** 即時篩選備註 (note) 包含該文字的交易（不區分大小寫）

#### Scenario: 篩選交易
- **WHEN** 使用者選擇篩選條件
- **THEN** 支援以下篩選（可組合）：
    - 分類（單選或多選）
    - 帳戶（單選或多選）
    - 日期區間（起始 ↔ 結束）
    - 標籤（單選或多選）
    - 類型（支出 / 收入 / 轉帳）

#### Scenario: 編輯交易
- **WHEN** 使用者點擊交易進入詳情頁後點擊「編輯」
- **THEN** 開啟新增交易 Sheet（預填現有資料）
- **AND** 儲存後更新交易並重新計算相關帳戶餘額
- **AND** `updatedAt` 自動更新

#### Scenario: 刪除交易
- **WHEN** 使用者在列表中左滑交易或在詳情頁點擊「刪除」
- **THEN** 顯示確認對話框（`.confirmationDialog`）
- **AND** 確認後永久刪除該交易
- **AND** 相關帳戶餘額自動重新計算

### Requirement: 驗證規則（Validation Rules）

#### Scenario: 新增交易驗證
- **WHEN** 使用者嘗試儲存交易
- **THEN** 以下欄位為必填：
    - `amount`：必須 > 0
    - `accountId`：必須選擇帳戶
    - `categoryId`：必須選擇分類（轉帳除外）
    - `date`：必須有值（預設今天）
- **AND** 若驗證失敗，在相關欄位顯示提示（不使用 alert，用 inline 錯誤提示）

### Requirement: TransactionFilter Type
The system SHALL provide a `TransactionFilter` struct for composable transaction filtering.

#### Scenario: TransactionFilter Definition
- **WHEN** filtering transactions with multiple criteria
- **THEN** a `TransactionFilter` struct SHALL be available with:
    - `categoryIds`: Set<Category.ID>? — filter by one or more categories (nil = all)
    - `accountIds`: Set<Account.ID>? — filter by one or more accounts (nil = all)
    - `tagIds`: Set<Tag.ID>? — filter by one or more tags (nil = all)
    - `types`: Set<TransactionType>? — filter by transaction type (nil = all)
    - `dateRange`: ClosedRange<Date>? — filter by date range (nil = all dates)
    - `searchText`: String? — filter by note text search (nil = no text filter)
- **AND** `TransactionFilter` SHALL conform to `Equatable` and `Sendable`.
- **AND** all `nil` values SHALL mean "no filter applied" for that criterion.

### Requirement: TransactionClient Interface
The `TransactionClient` SHALL include search and filter capabilities.

#### Scenario: TransactionClient Definition
- **WHEN** a Client is defined in `Features/Domain/Clients/TransactionClient.swift`
- **THEN** its interface SHALL be:

```swift
@DependencyClient
public struct TransactionClient: Sendable {
    public var fetchRecent: @Sendable () async throws -> [Transaction]
    public var fetchAll: @Sendable () async throws -> [Transaction]
    public var fetch: @Sendable (TransactionFilter) async throws -> [Transaction]
    public var search: @Sendable (String) async throws -> [Transaction]
    public var add: @Sendable (Transaction) async throws -> Void
    public var update: @Sendable (Transaction) async throws -> Void
    public var delete: @Sendable (Transaction.ID) async throws -> Void
}
```

- **AND** `fetchByAccount` and `fetchByCategory` are **REMOVED** — replaced by `fetch(filter:)`.
- **AND** `search` provides text search against transaction `note` field.
- **AND** `fetch(filter:)` supports composable filtering by category, account, tag, type, date range, and text.
