## Why

Domain 模組的 Code Review 發現實作與 OpenSpec 規格之間存在顯著差異。`AIServiceClient` 的介面與 `ai-integration.md` 幾乎完全不符，缺少 `TagClient`、`BudgetClient` 兩個業務必要的 Client 介面，`TransactionClient` 和 `AccountClient` 也缺少規格中要求的搜尋、篩選與餘額計算能力。此外，整個 Domain 模組尚無任何單元測試。在這個階段修正可以避免問題傳遞至 Data 與 Features 層。

## What Changes

- **BREAKING** — 重寫 `AIServiceClient`：移除不符規格的 `analyzeReceipt(Data)` 方法，替換為 `extractTransaction(String)`、`suggestCategories(String, [String])`、`generateInsight(SpendingSummary)` 和 `isAvailable()` 四個方法。移除 `TransactionParseResult`，新增 `ExtractedTransaction`、`CategorySuggestions`、`SpendingSummary` 三個關聯型別。
- 新增 `TagClient`：提供標籤的 fetchAll、add、update、delete 介面，對應 `app-features.md` 標籤管理需求。
- 新增 `BudgetClient`：提供預算的 fetchAll、fetchActive、add、update、delete 介面，對應 `app-features.md` 預算管理需求。
- 擴充 `TransactionClient`：新增 `search(String)`（備註搜尋）與 `fetch(filter: TransactionFilter)` 方法，並定義 `TransactionFilter` 結構體，支援分類 / 帳戶 / 日期區間 / 標籤 / 類型的組合篩選。
- 擴充 `AccountClient`：新增 `computeBalance(Account.ID)` 方法，支援 Dashboard 的即時餘額顯示。
- 所有 Entity 加上 `Hashable` 協定，確保與 TCA `IdentifiedArray` 及 SwiftUI 良好配合。
- 為所有 Enum、Entity 與 Client 建立完整的單元測試。

## Capabilities

### New Capabilities
- `domain-unit-tests`: 為 Domain 模組的 Enums、Entities 和 Clients 建立完整的單元測試覆蓋，包含初始化驗證、Codable 編解碼、Equatable 比較、預設值與邊界條件測試。

### Modified Capabilities
- `domain-model`: 所有 Entity 新增 `Hashable` 協定。
- `ai-integration`: `AIServiceClient` 介面重新定義，移除 `analyzeReceipt` 改為 `extractTransaction`、`suggestCategories`、`generateInsight`、`isAvailable` 四個方法，並新增關聯型別。
- `app-features`: 新增 `TagClient`、`BudgetClient` 兩個 Client 介面；`TransactionClient` 新增搜尋/篩選能力及 `TransactionFilter` 型別；`AccountClient` 新增餘額計算能力。

## Impact

- **Domain 模組**：`Sources/Domain/Clients/` 內所有 4 個 Client 檔案都會被修改，另新增 2 個 Client 檔案（`TagClient.swift`、`BudgetClient.swift`）。在 `Sources/Domain/Entities/` 中新增 `TransactionFilter.swift` 以及 AI 相關型別檔案。所有 Entity 的協定宣告更新。
- **Tests**：`Tests/DomainTests/` 新增多個測試檔案，涵蓋 Enums、Entities、Clients 的測試。
- **破壞性變更**：`AIServiceClient` 的公開 API 完全改變，任何已使用 `analyzeReceipt` 或 `TransactionParseResult` 的程式碼都需要同步更新（目前尚無下游消費者，因此影響範圍可控）。
- **依賴**：無新增外部依賴，仍使用 `swift-dependencies`。
