# Apple Watch 功能設計 Spec

**日期：** 2026-05-27
**狀態：** Design Approved（待 writing-plans）
**作者：** Drake + Claude

---

## 1. Scope & Goals

### MVP 交付項目

1. 獨立 watchOS App target，最小化 3 步快速記帳：分類 → 金額 → 存檔
2. 長按分類 → 彈帳戶選單（單次覆寫，不改預設）
3. 一個 Complication — `TodayExpenseComplication`（今日支出總額），支援 `.accessoryCircular` / `.accessoryCorner` / `.accessoryRectangular` / `.accessoryInline` 四種 family
4. WatchConnectivity 雙向通訊；Watch 只持有最小快取，不存交易主資料
5. Watch 端 UI 沿用既有 Design System（Liquid Glass、`Font.Design`、`Color.Design`）

### 非目標（明確排除）

- 語音備註（延後）
- 在 Watch 上瀏覽歷史交易、編輯 / 刪除舊交易
- Watch 上設定預算、分類、帳戶
- AI 分類建議（Watch 端）
- 多種 Complication family 各自顯示不同資料
- 收入、轉帳的 Watch 端記錄（MVP 只記支出）
- iOS Lock Screen widgets（既有 `NeuLedgerWidget` 已負責）

### 驗收條件

- 使用者從抬腕到完成一筆記帳 ≤ 10 秒（連線正常時）
- 離線（iPhone 不在身邊或藍牙斷）時 Watch 仍可記帳，恢復連線後自動補送
- iPhone 端 SwiftData 寫入後，Complication 在 30 秒內反映新數字

---

## 2. Architecture

### Target 配置

```
NeuLedger.xcodeproj
├── NeuLedger (iOS App)                  ← 既有
├── NeuLedgerWidget (iOS extension)      ← 既有
├── NeuLedgerWatch (watchOS App)         ← 新增，single-target watch app
└── NeuLedgerWatchComplication           ← 新增，watchOS WidgetKit extension
```

watchOS 26 使用 single-target watch app，不再需要 companion target / WKExtension 拆分。

### SPM 套件結構

```
Features/Sources/
├── Domain/        ← 既有，新增 WatchBridgeClient interface + 兩個 model
├── Core/          ← 既有，新增 iPhone 端 WC bridge live 實作
├── Common/        ← 既有，部分元件以 #if os 拆 iOS / watchOS
├── Features/      ← 既有，iOS 專用
└── WatchFeatures/ ← 新增 SPM target，只給 NeuLedgerWatch target 連結
```

### 依賴方向

```
NeuLedgerWatch (App)
        ↓
WatchFeatures   ←  Core  ←  Domain
        ↓          ↓
      Common  ─────┘
```

`WatchFeatures` 不直接 import SwiftData，仍透過 `@Dependency`。

### 通訊邊界職責

| 元件 | 位置 | 職責 |
|---|---|---|
| `WatchBridgeClient` | Domain | `pushContext` 介面（iPhone → Watch 推送 snapshot） |
| `WatchBridgeClient.liveValue` | Core（iOS） | wrap `WCSession`；`updateApplicationContext` |
| `WatchSessionDelegate` | Core（iOS） | iPhone 端 `WCSessionDelegate`；接收 Watch 送來的 `TransactionDraft`，呼叫 `transactionClient.add` |
| `WatchContextBuilder` | Core（iOS） | 從 SwiftData 組出 `WatchContextSnapshot`（今日總額、預算進度） |
| `WatchSyncObserver` | Core（iOS） | 監聽 SwiftData / SyncClient 變動，rebuild snapshot 後 push |
| `WatchSessionGateway` | Core（watchOS） | Watch 端 `WCSessionDelegate`；收 context、寫 cache、reload widget timeline |
| `WatchCacheStore` | Core（watchOS） | App Group `UserDefaults` 快取 `WatchContextSnapshot` |
| `Watch{Transaction,Category,Account}Client+Live` | Core（watchOS） | Watch 版實作；`add` 走 WC，read 從 cache |

### 資料流（雙向）

**Watch → iPhone（記一筆）：**

```
[Watch] 使用者按確認
  → Watch TransactionClient.add(draft)
  → WatchSessionGateway.send(.addTx, draft)
  → WCSession.transferUserInfo([...])       ← 保證最終送達，可離線排隊
================== iPhone ==================
  → WatchSessionDelegate didReceiveUserInfo
  → 去重檢查（用 draft 帶的 UUID）
  → TransactionClient.add(tx)                ← 既有 live client，寫 SwiftData
  → SwiftData 變動 → CloudKit 自動同步到其他裝置
```

**iPhone → Watch（推 context）：**

```
[iPhone] SwiftData ModelContext didSave
  → WatchSyncObserver 偵測
  → WatchContextBuilder.build()
  → WatchBridgeClient.pushContext(snapshot)
  → WCSession.updateApplicationContext([...])  ← 永遠只保留最新一份
================== Watch ==================
  → WatchSessionGateway didReceiveApplicationContext
  → WatchCacheStore.save(snapshot)
  → SwiftUI Observation 自動重繪
  → WidgetCenter.reloadAllTimelines()
```

### 為什麼用 `transferUserInfo`（而非 `sendMessage`）

- `sendMessage` 要求 reachable，無法離線送 → 不適合「離線記帳」場景
- `transferUserInfo` 排隊保證最終送達，符合 MVP 驗收條件

### 為什麼 Watch 不直接接 CloudKit

- CloudKit 延遲 5-30 秒，快速記帳體驗會卡
- 要 Watch 端也接 CloudKit 等於整份 SwiftData schema + Mapper + Client 都要搬一份，違反「Watch 是輕量端」
- Watch → iPhone 走 WC，iPhone → 其他裝置走既有 CloudKit Sync，職責清晰

---

## 3. UI Flow（Watch 端）

### 主流程：3 個畫面 stack

```
┌─ Screen 1: 分類網格 ────┐    ┌─ Screen 2: 金額鍵盤 ──┐    ┌─ Screen 3: 確認 ────┐
│  ┌───┐ ┌───┐ ┌───┐    │    │       NT$ 480         │    │  ☕ 餐飲              │
│  │🍔 │ │🚗 │ │🛒 │    │ →  │  ┌─┐ ┌─┐ ┌─┐         │ →  │  NT$ 480              │
│  └───┘ └───┘ └───┘    │    │  │7│ │8│ │9│         │    │  現金                  │
│  ┌───┐ ┌───┐ ┌───┐    │    │  ├─┤ ├─┤ ├─┤         │    │                       │
│  │🎬 │ │💊 │ │📚 │    │    │  │4│ │5│ │6│         │    │  [ 確認  ]            │
│  └───┘ └───┘ └───┘    │    │  └─┘ └─┘ └─┘         │    │  [ 取消  ]            │
│  ⌃ 更多分類            │    │  ⌫  完成              │    │                       │
└───────────────────────┘    └───────────────────────┘    └───────────────────────┘
```

### Screen 1：分類網格

- 來源：`WatchCacheStore.categories.filter { $0.type == .expense }`
- 3 欄網格，圓形 icon button（`SDCategory.color` + SF Symbol）
- **點擊**：選定分類 → push 到 Screen 2
- **長按（haptic）**：彈出 `.sheet` 列出 `accounts.filter { !$0.isArchived }`，使用者選後帶該帳戶進 Screen 2（本次覆寫）；未選則用 `defaultAccountId`
- Digital Crown 滾動長清單
- 空清單狀態：「請先在 iPhone 開啟並設定分類」+ 解釋文

### Screen 2：金額鍵盤

- 大字金額（`Font.Design` 中的 monospaced rounded 大字 token，例如 `size22SemiboldRounded`）
- 自製 3×4 數字鍵盤（0-9、⌫、✓）
- TWD 整數，無小數點
- 0 不能送出；上限 NT$ 9,999,999（7 位數）
- ✓ → 到 Screen 3
- 左滑 / Digital Crown 短壓 = 回 Screen 1

### Screen 3：確認

- 摘要：icon + 分類名 + 金額 + 帳戶名
- `PrimaryButton` 風格 [確認]（Liquid Glass prominent）+ secondary [取消]
- 確認 → 樂觀 UI（立刻回主畫面，不等 iPhone ack）→ haptic `.success`
- 取消 → 回 Screen 2 修改

### App 進入點

- App icon：落在 Screen 1
- Complication tap：落在 Screen 1（無 deep link 差異）

### TCA 結構

- `WatchRecordFeature` 持 stack-based navigation：`StackState<Path.State>`
- `Path` 三個 case：`.category` / `.amount(categoryId, accountIdOverride?)` / `.confirm(draft: TransactionDraft)`
- 確認後送 `delegate(.recorded)`，由根 reducer 處理 dismiss + haptic

### 互動限制

- Force Touch 自 watchOS 7 已移除，不設計 Force Touch 動作
- Digital Crown 僅用於 Screen 1 滾動

---

## 4. Complication

### 範圍

一個 widget — `TodayExpenseComplication`，今日支出總額。

### 支援的 families

| Family | 呈現 |
|---|---|
| `.accessoryCircular` | 環形小元件。顯示金額（monospaced semibold）+ 上方小字 "今日" |
| `.accessoryCorner` | 錶面角落弧形。金額 + corner gauge 顯示本月總預算進度（若有設總預算才畫弧度） |
| `.accessoryRectangular` | 矩形長條。第一行 label "今日支出"，第二行金額（大），第三行 "X 筆交易" |
| `.accessoryInline` | 文字行。「今日 NT$ 480」 |

### 資料來源

- 從 `WatchCacheStore`（App Group 共用 UserDefaults）讀 `todayTotal: Int`、`todayCount: Int`、`monthBudgetProgress: Double?`
- Watch App + Complication 共用 App Group capability

### Timeline policy

- `TimelineProvider` 提供「現在」一個 entry，policy = `.never`
- 重新整理完全靠 push（`WidgetCenter.reloadAllTimelines()`），不靠 timeline 預先排程
- 跨日處理：iPhone 端在午夜（或 App active 時偵測日期變更）主動推一份 context，`todayTotal` 重設為 0

### 降級行為

- 首次安裝、尚未收到任何 context → 顯示 "—"（避免「NT$ 0」誤導）
- iPhone App 從未啟動過 → 同上

### 點擊行為

開啟 Watch App 落在 Screen 1（分類網格）。

---

## 5. Layer Changes

### Domain 層（新增）

```swift
// Domain/Clients/WatchBridgeClient.swift
@DependencyClient
public struct WatchBridgeClient: Sendable {
    public var isPaired: @Sendable () -> Bool = { false }
    public var isWatchAppInstalled: @Sendable () -> Bool = { false }
    public var pushContext: @Sendable (WatchContextSnapshot) async throws -> Void
}

// Domain/Models/WatchContextSnapshot.swift
public struct WatchContextSnapshot: Codable, Equatable, Sendable {
    public let categories: [Category]
    public let accounts: [Account]
    public let defaultAccountId: UUID
    public let todayTotal: Int
    public let todayCount: Int
    public let monthBudgetProgress: Double?   // nil = 未設總預算
    public let snapshotAt: Date
}

// Domain/Models/TransactionDraft.swift
public struct TransactionDraft: Codable, Equatable, Sendable {
    public let id: UUID                       // 用於 iPhone 端去重
    public let categoryId: UUID
    public let accountId: UUID
    public let amount: Int
    public let date: Date                     // 預設 .now
}
```

既有的 `TransactionClient` / `CategoryClient` / `AccountClient` / `BudgetClient` 介面**不動**。

### Core 層 — iPhone 端（新增）

| 檔案 | 職責 |
|---|---|
| `Core/Watch/WatchBridgeClient+Live.swift` | `WatchBridgeClient.liveValue`，wrap `WatchSessionTransport` |
| `Core/Watch/WatchSessionTransport.swift` | protocol 包裝 `WCSession`，便於測試 |
| `Core/Watch/WatchSessionDelegate.swift` | `WCSessionDelegate`；收 `TransactionDraft`、去重後呼叫 `transactionClient.add` |
| `Core/Watch/WatchContextBuilder.swift` | 從 SwiftData 組 `WatchContextSnapshot` |
| `Core/Watch/WatchSyncObserver.swift` | 監聽 ModelContext didSave / SyncClient，觸發 `pushContext` |
| `Core/Watch/ProcessedDraftIdsStore.swift` | UserDefaults-backed 去重清單（保留最近 N 筆 id） |

iPhone App 啟動時（`AppFeature.task`）：
1. 啟動 `WCSession`
2. 啟動 `WatchSyncObserver`
3. 主動推一次當前 snapshot（保險）

### Core 層 — Watch 端（新增）

| 檔案 | 職責 |
|---|---|
| `Core/Watch/WatchSessionGateway.swift` | Watch 端 `WCSessionDelegate`；收 context、寫 cache、reload widget timeline |
| `Core/Watch/WatchCacheStore.swift` | Codable snapshot ↔ App Group `UserDefaults` |
| `Core/Watch/WatchTransactionClient+Live.swift` | `TransactionClient.add` 走 gateway.send；其他方法不實作（live 端 fatalError，但 reducer 不會呼叫） |
| `Core/Watch/WatchCategoryClient+Live.swift` | 從 `WatchCacheStore` 讀 |
| `Core/Watch/WatchAccountClient+Live.swift` | 從 `WatchCacheStore` 讀 |

### Common 層條件編譯

- `Font.Design` / `Color.Design` 沿用，必要時用 `#if os(iOS)` / `#if os(watchOS)` 拆 iOS-only API（例如 `UIColor`）
- `GlassCard`、`PrimaryButton` 預期需 fork Watch 變體，token 名稱保持一致

### 設定 / 預設值

- iPhone 端 `UserSettings` 新增 key：`watchDefaultAccountId: UUID?`
- Settings 畫面新增「Apple Watch」section：配對狀態 + Watch 預設帳戶選擇器
- 預設值：種子帳戶「現金」的 UUID

---

## 6. Testing

### Domain 層（新增單元測試）

- `WatchContextSnapshotTests` — Codable round-trip、Equatable
- `TransactionDraftTests` — Codable round-trip、`amount > 0` 驗證
- `WatchBridgeClientTests` — `\.watchBridgeClient` 可取到 testValue

### Core 層 — iPhone 端

- `WatchContextBuilderTests` — 用 `DatabaseClient.testValue` 塞測資（今日 / 非今日、有 / 無預算），驗證 snapshot 內容
- `WatchSessionDelegateTests` — 模擬收到 `TransactionDraft`，驗證去重 + `transactionClient.add` 被呼叫
- `ProcessedDraftIdsStoreTests` — 去重 / 容量上限行為

### Core 層 — Watch 端

- `WatchCacheStoreTests` — encode/decode、空快取、覆寫不殘留欄位
- `WatchTransactionClient_LiveTests` — `add(_:)` 是否呼叫 transport.send 且 payload 正確

### Features 層 — Watch 端 reducer

- `WatchRecordFeatureTests`（TCA TestStore）：
  - 完整 3 步路徑（選分類 → 輸入金額 → 確認）
  - 長按分類覆寫帳戶
  - 取消
  - 空快取（首次安裝）UI state

### 整合 / 手動測試（不寫自動測試）

- Watch ↔ iPhone 真機配對
- Complication 各 family 視覺
- 跨日（午夜）總額重設
- iPhone 殺 process 後 Watch 寫一筆 → iPhone 重啟後仍能補收

### 新增 test target

- `NeuLedgerWatchTests`（watchOS Swift Testing target）
- iPhone 端新測試放現有 `NeuLedgerTests`

---

## 7. Risks / Open Questions / Rollout

### 已知風險與對策

| 風險 | 對策 |
|---|---|
| `transferUserInfo` 在重啟、低電量、背景的排隊行為複雜 | 樂觀 UI 立刻回主畫面；iPhone 端冪等去重（`TransactionDraft.id`） |
| `updateApplicationContext` 只保留最新一份；連續寫多筆 Watch 只看到最後一份 context | builder 永遠送完整 snapshot，不送 delta |
| Complication policy `.never`，完全靠 push 刷新 | Gateway 收到 context 必 reload；iPhone 端午夜 trigger 須走 |
| `Common` 元件可能用 iOS-only API | 進實作前盤點，逐個 `#if os` 拆 |
| Watch 端無 `userSettingsClient` | Watch 不需 settings；預設帳戶從 snapshot 帶 |

### Open questions（不卡 spec）

1. iPhone Settings 的「Apple Watch」section 是否顯示配對狀態 visual indicator？傾向做
2. `WatchSessionTransport` protocol 放 Domain 還是 Core？傾向 Core（薄 wrapper、非 domain 概念）
3. Watch 端記錄成功的回饋：`WKInterfaceDevice.current().play(.success)` + 視覺確認？傾向做

### Rollout 順序（給 writing-plans 參考）

**Phase 1 — 通訊地基（無 UI）**
1. Domain：`WatchBridgeClient` interface、`WatchContextSnapshot`、`TransactionDraft`
2. Core：`WatchSessionTransport` protocol + `WCSession` 實作
3. Core：`WatchContextBuilder` + 單元測試
4. Core：`WatchSessionDelegate`（iPhone）+ 冪等去重

**Phase 2 — Watch App 主流程**

5. 新增 `NeuLedgerWatch` target + `WatchFeatures` SPM target
6. Watch 端 `WatchSessionGateway` + `WatchCacheStore`
7. Watch 端 client live 實作
8. `WatchRecordFeature` reducer + tests
9. 三個 Screen view

**Phase 3 — Complication**

10. `NeuLedgerWatchComplication` target
11. `TodayExpenseComplication`（四個 families）
12. `WidgetCenter` reload 串連

**Phase 4 — Settings 收尾**

13. iPhone Settings 新增 Watch section（預設帳戶選擇）
14. 跨日重設邏輯（午夜 trigger / app active 偵測）
15. 手動實機測試 checklist

---

## 附錄：和既有設計的關係

- **iCloud Sync**（`2026-04-01-icloud-sync-design.md`）：已落地。Watch 不直接接 CloudKit；Watch → iPhone 走 WC，iPhone 端寫入後自動透過既有 SyncClient 同步到其他裝置
- **Widget**（`2026-04-06-widget-design.md` / `2026-05-16-carrier-widget-configurable-design.md`）：iOS 端 Lock Screen widgets，與 Watch Complication 各自獨立 target，不共用程式碼但共用 Domain
- **Voice Note Input**（`2026-03-30-voice-note-input-design.md`）：iPhone 端語音記帳。Watch 端 MVP **不做**語音；未來若做，可考慮「Watch dictation → WC 送原文 → iPhone 用 Foundation Models 抽取」的延伸路徑
