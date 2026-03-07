## Context

目前 `MainTabFeature` 的 `Tab.search` 是空白 placeholder，`AddTransactionFeature` 是僅有 dismiss action 的 placeholder reducer。使用者可以從 Dashboard 開啟新增交易 Sheet，但無法查看交易列表、搜尋、篩選、編輯或刪除交易。

此 change 的範圍涵蓋：
1. 完整實作 `AddTransactionFeature`（支援新增與編輯模式）
2. 新增 `TransactionsFeature` + `TransactionsView`（列表、搜尋、篩選）
3. 新增 `TransactionDetailFeature` + `TransactionDetailView`（詳情 + 刪除）
4. 更新 `MainTabFeature` / `MainTabView` 整合 Transactions tab

## Goals / Non-Goals

**Goals:**
- 完成完整的交易 CRUD 體驗（Create 已在 Dashboard，補齊 Read/Update/Delete）
- Transactions tab 支援搜尋（即時過濾）與多條件篩選
- `AddTransactionFeature` 支援新增模式與編輯模式（預填資料）

**Non-Goals:**
- AI 輔助記帳整合（`AddTransactionFeature` 內的 AI 欄位預留 hook 即可，實際 AI 呼叫留待後續）
- 標籤選擇器 UI（篩選器支援 tagIds，但 AddTransaction 的 tag 選擇留待後續）
- 匯出 CSV/JSON（屬於 Settings 功能）
- 帳戶管理、分類管理畫面（屬於 Settings 子頁）

## Decisions

### Decision 1：`AddTransactionFeature` 以 `mode` 區分新增 vs 編輯

**選擇**：在 `AddTransactionFeature.State` 中加入 `enum Mode { case add(TransactionType); case edit(Transaction) }`，用 pattern matching 決定初始值與儲存行為。

**理由**：兩個模式共用相同的表單欄位（金額、帳戶、分類、備註、日期），差異僅在初始預填值與儲存時呼叫 `add` vs `update`。獨立兩個 Reducer 會造成程式碼重複。

**替代方案考慮**：拆分為 `AddTransactionFeature` 與 `EditTransactionFeature` → 重複邏輯過多，拒絕。

---

### Decision 2：`TransactionsFeature` 使用 `@Presents` 呈現詳情頁（Sheet 或 FullScreenCover）

**選擇**：`TransactionsFeature.State` 持有 `@Presents var detail: TransactionDetailFeature.State?`，點擊交易 row 後以 sheet 呈現詳情。

**理由**：詳情頁是模態展示，符合 iOS 慣例（非全頁 push）。TCA tree-based navigation 的 `@Presents` 比 stack navigation 更適合「單層詳情」場景。

**替代方案考慮**：stack-based push → 適合多層深度導航，此場景只有一層詳情，overkill。

---

### Decision 3：篩選 Sheet 以獨立的 `FilterFeature` 實作

**選擇**：`TransactionsFeature.State` 持有 `@Presents var filter: FilterFeature.State?`，篩選 Sheet 由獨立 Reducer 管理，套用後透過 delegate 回傳 `TransactionFilter`。

**理由**：篩選邏輯（載入所有分類/帳戶/標籤選項、多選狀態管理）需要自己的 State，與列表畫面解耦便於測試。

---

### Decision 4：搜尋使用 debounce 避免過度觸發

**選擇**：`TransactionsFeature` 在收到 `.searchTextChanged` action 後，以 `.debounce(id:, for: 0.3s)` 再觸發 `transactionClient.search(text)` 或重新套用 filter。

**理由**：即時搜尋若每次 keystroke 都直接呼叫 client，會產生不必要的 SwiftData 查詢。0.3 秒的 debounce 符合使用者感知的即時性。

---

### Decision 5：`Tab.search` 改名為 `Tab.transactions`（BREAKING）

**選擇**：直接在 `MainTabFeature.Tab` enum 中將 `.search` 改為 `.transactions`，更新所有引用處。

**理由**：tab 的職責是顯示交易記錄而非搜尋，命名需反映實際功能。搜尋是 Transactions tab 內的子功能，不是獨立 tab。

---

### Decision 6：`TransactionDetailFeature` 持有 `@Presents` 進入編輯模式

**選擇**：`TransactionDetailFeature.State` 持有 `@Presents var editTransaction: AddTransactionFeature.State?`，「編輯」按鈕以 `.edit(transaction)` mode 呈現 AddTransaction Sheet。

**理由**：重用 `AddTransactionFeature` 避免重複表單邏輯，與 Dashboard 新增流程保持一致。

## Risks / Trade-offs

- **`AddTransactionFeature` 從 placeholder 到完整實作的範圍擴大**：此 change 包含完整的表單欄位實作，工作量較預期大。
  → 緩解：先完成核心欄位（金額、帳戶、分類、備註、日期），AI 與 tag 選擇保留 placeholder hook。

- **`Tab.search` → `Tab.transactions` 的 BREAKING 改名**：可能影響 snapshot test 或外部參照。
  → 緩解：統一在單一 commit 中更新所有引用，無舊 API 需要維持向後相容。

- **`FilterFeature` 需要在 Sheet 開啟時載入分類/帳戶/標籤清單**：若資料量大，首次開啟可能有短暫延遲。
  → 緩解：篩選 Sheet 使用 `.task` 非同步載入，顯示 loading indicator。
