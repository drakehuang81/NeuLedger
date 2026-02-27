## Context

NeuLedger 的 Domain 模組是 Clean Architecture 的核心層，包含純 Swift 的 Entities、Enums 與 Client 介面定義。目前已完成初版實作，但 Code Review 揭露了多項與 OpenSpec 規格的偏差，主要集中在 `AIServiceClient` 介面不符、缺少 `TagClient`/`BudgetClient`、以及 `TransactionClient`/`AccountClient` 介面不完整。此外，Domain 模組尚無任何單元測試。

目前的 Domain 模組結構：
```
Sources/Domain/
├── Enums/         (4 files: TransactionType, AccountType, Currency, BudgetPeriod)
├── Entities/      (5 files: Transaction, Account, Category, Tag, Budget)
└── Clients/       (4 files: TransactionClient, AccountClient, CategoryClient, AIServiceClient)
```

外部依賴：`swift-dependencies`（提供 `@DependencyClient`、`TestDependencyKey`、`DependencyValues`）

## Goals / Non-Goals

**Goals:**
- 使所有 Domain Client 介面與 OpenSpec 規格完全一致
- 為 Domain 模組建立完整的單元測試覆蓋
- 確保所有型別與 TCA (`IdentifiedArray`) 及 SwiftUI 良好配合
- 保持 Domain 層的純粹性：不引入任何外部框架依賴（`FoundationModels`、`SwiftData` 等）

**Non-Goals:**
- 不實作 Client 的 `liveValue`（屬於 Data 層職責）
- 不建立 Feature 層的 Reducer 或 View
- 不變更 `Package.swift` 的外部依賴（`swift-dependencies` 已足夠）
- 不處理 UI 相關的設計系統組件

## Decisions

### D1：AIServiceClient 的 AI 相關型別放在 Domain 而非獨立模組

**選擇**：將 `ExtractedTransaction`、`CategorySuggestions`、`SpendingSummary` 定義在 `Domain/Entities/` 資料夾中

**替代方案**：建立獨立的 `AIModels` 模組
**理由**：這些型別是 Domain Client 介面的直接參數與回傳值，屬於 Domain 契約的一部分。獨立模組會增加不必要的複雜度。它們是純 Swift struct，不依賴 `FoundationModels`（`@Generable` 標註會在 Data 層的 live implementation 中處理）。

### D2：TransactionFilter 使用 Struct 而非多個獨立方法

**選擇**：定義 `TransactionFilter` struct，提供單一 `fetch(filter:)` 方法

```swift
public struct TransactionFilter: Equatable, Sendable {
    public var categoryIds: Set<Category.ID>?
    public var accountIds: Set<Account.ID>?
    public var tagIds: Set<Tag.ID>?
    public var types: Set<TransactionType>?
    public var dateRange: ClosedRange<Date>?
    public var searchText: String?
}
```

**替代方案**：為每種篩選條件各定義一個 fetch 方法（`fetchByTag`、`fetchByDateRange` 等）
**理由**：`app-features.md` 明確要求「篩選可組合」。用單一 Filter struct 可以自然地組合多個條件，而多個獨立方法無法處理交集篩選（例如同時篩選分類 + 日期 + 標籤）。同時移除目前的 `fetchByAccount` 和 `fetchByCategory`，統一由 `fetch(filter:)` 取代，減少 API 表面積。

### D3：保留單獨的 `search` 方法，不合併進 `fetch(filter:)`

**選擇**：`TransactionClient` 同時保有 `search(String)` 和 `fetch(filter:)`

**替代方案**：只用 `fetch(filter:)` 的 `searchText` 欄位
**理由**：`search` 是 UI 層最常用的即時操作（每次鍵入都觸發），需要獨立的方法來優化效能（例如 debounce、local cache），而 `fetch(filter:)` 適合更複雜的篩選場景。保持兩者讓消費端有清晰的語義區分。

### D4：Entity 加上 Hashable 使用自動合成

**選擇**：讓所有 Entity 遵循 `Hashable`，使用 Swift 自動合成

**替代方案**：手動實作 `hash(into:)` 只 hash `id` 欄位
**理由**：所有欄位型別（`UUID`、`String`、`Decimal`、`Date`、`Bool`、`Int`、`[Tag]`、`Optional<...>`）本身已是 `Hashable`，自動合成即可。如未來遇到效能瓶頸再考慮只 hash `id`。

### D5：AIServiceClient.isAvailable 使用同步方法而非 async

**選擇**：`var isAvailable: @Sendable () -> Bool`（同步）

**替代方案**：`var isAvailable: @Sendable () async -> Bool`
**理由**：`ai-integration.md` 規格中 `SystemLanguageModel.default.isAvailable` 是同步屬性。AI 可用性是 UI 判斷是否顯示 AI 功能的前提，同步結果讓 View 層可以直接使用而無需 async 處理。

### D6：單元測試策略 — 按層級分檔

**選擇**：按照 Enums / Entities / Clients 分別建立測試檔案

```
Tests/DomainTests/
├── Enums/
│   ├── TransactionTypeTests.swift
│   ├── AccountTypeTests.swift
│   ├── CurrencyTests.swift
│   └── BudgetPeriodTests.swift
├── Entities/
│   ├── TransactionTests.swift
│   ├── AccountTests.swift
│   ├── CategoryTests.swift
│   ├── TagTests.swift
│   ├── BudgetTests.swift
│   └── TransactionFilterTests.swift
└── Clients/
    ├── TransactionClientTests.swift
    ├── AccountClientTests.swift
    ├── CategoryClientTests.swift
    ├── TagClientTests.swift
    ├── BudgetClientTests.swift
    └── AIServiceClientTests.swift
```

**理由**：與 Sources 結構鏡像對應，方便定位。每個測試檔案專注測試一個型別的初始化、Codable 編解碼、Equatable 比較、預設值等。Client 測試主要驗證 `TestDependencyKey` 正確配置和 `DependencyValues` 存取。

## Risks / Trade-offs

| 風險 | 影響 | 緩解措施 |
|------|------|----------|
| `AIServiceClient` BREAKING 改動 | 若有下游已依賴舊 API 會無法編譯 | 目前 Domain 無下游消費者（Data、Features 尚未實作），影響可控 |
| `TransactionFilter` 的 `Set<ID>?` 使用 `nil` 代表「不篩選」 | 語義可能不夠明確 | 統一在文件中註明 `nil` = all，非開發者直觀 |
| 移除 `fetchByAccount` / `fetchByCategory` 獨立方法 | 簡單場景需要建構 Filter struct | 可提供 `TransactionFilter` 的 convenience init 簡化常用篩選 |
| Domain 層 AI 型別（`ExtractedTransaction` 等）不帶 `@Generable` 標註 | Data 層需要另建帶標註的型別或 extension | 設計上這是正確的分層 — Domain 不應依賴 `FoundationModels`；Data 層添加 `@Generable` conformance |
