# Watch 載具功能設計

**日期**：2026-06-05
**狀態**：已與用戶逐段核可

## 1. 背景與目標

watchOS app 目前只有單一「快速記帳」功能（分類 → 金額 → 確認三步驟狀態機）。本功能新增**電子發票載具**能力：使用者結帳時抬手即可出示載具條碼供店員掃描，不必掏出 iPhone。

成功標準：

1. 從錶面開 app → 上滑 → 看到條碼，全程 ≤ 2 個手勢（單張載具情境）
2. 條碼可被超商 POS 掃描器實際讀取（手機條碼與自然人憑證皆是）
3. iPhone 端載具增刪改後，watch 自動同步，無需手動操作
4. 既有記帳流程完全不受影響

## 2. 範圍

### In scope

- watch 端「記帳 ↔ 載具」垂直翻頁切換（TabView `.verticalPage`）
- watch 載具頁四態：未同步提示 / empty 引導 / 列表（2+ 張）/ 全螢幕條碼
- iPhone → watch 的載具鏡像（擴充既有 `WatchContextSnapshot` 管線）
- 純 Swift Code 128 編碼器 + SwiftUI 條碼 View（Common 層）

### Out of scope（記錄但不做）

- watch 端新增/編輯/刪除載具（**唯讀檢視** — 用戶裁定；新增一律在 iPhone）
- 「啟用中載具」（`activeForWidget`）鏡像到 watch — 智慧快路徑不需要 active 概念
- 載具 complication（未來可考慮）
- iOS app / widget 改用新 Code 128 元件消除兩份重複的 `CIFilter` 實作（列為 follow-up）
- watch 上行管道擴充（維持只有 `addTx` 一種 op）

## 3. 用戶決策記錄

| 決策點 | 選定 | 備註 |
|---|---|---|
| watch 載具能力範圍 | **唯讀檢視** | 不動上行管道，風險最低 |
| 切換入口 | **垂直翻頁**（TabView `.verticalPage`） | watchOS 10+ 系統慣例 |
| 條碼方向 | **直式滿版**（轉 90° 吃滿螢幕高度） | 初選橫式，經掃描餘裕數據討論後改直式：手機條碼 ~3.4px/模組、憑證 ~2.9px/模組（45mm 錶、含 B+C 混編），皆高於 ~2.5px 經驗安全線 |
| 載具頁結構 | **智慧快路徑** | 0 張 → empty；1 張 → 直接條碼；2+ 張 → 列表 |
| 條碼產生 | **watch 端純 Swift 自繪**（方案 A） | 不採 iPhone 預渲染圖（payload 膨脹）與純文字降級版 |

## 4. 架構與資料流

### 4.1 各層改動

| 層 | 改動 |
|---|---|
| **Domain** | `WatchContextSnapshot` 加 `carriers: [Carrier]?`（optional，保舊版解碼相容） |
| **Core** | `WatchContextBuilder` 注入 `@Dependency(\.carrierClient)`，`listAll()` 打包進 snapshot（先例：`planningClient.listActive`） |
| **Common** | 新增 `Code128` 編碼器 + `Code128BarcodeView`（皆零外部依賴）；`Color.Design` 加 `barcodeSurface` / `barcodeInk` token |
| **WatchFeatures** | 新增 `WatchCarrierClient`（讀 cache；介面 `carriers() async -> [Carrier]?`，`nil` = 尚未同步、`[]` = 零張，語意直通 UI 四態）、`WatchCarrierFeature` + 畫面、新 root `WatchAppFeature`（Scope 組合記帳 + 載具） |
| **watch app target** | `@main` 改掛 `WatchAppFeature` root；載具字串加進 watch target 的 `Localizable.xcstrings`（`watch_` 前綴） |

### 4.2 資料流（零 transport 改動）

```
iPhone: CarrierStore 增刪改 → context.save()
  → WatchSyncObserver（既有：監聽 NSManagedObjectContextDidSave，debounce 300ms）
  → WatchContextBuilder.build()（改動點：多撈 carrierClient.listAll()）
  → WatchBridgeAdapter.pushContext（既有：updateApplicationContext 全量快照）
watch: WatchSessionGateway（既有）→ WatchCacheStore（既有：新欄位隨 JSON 自動落地）
  → didUpdateNotification → WatchCarrierFeature 重新載入
```

### 4.3 關鍵架構決策

1. **`carriers` 為 optional**：`nil` =（尚未同步 / iPhone 版本舊）、`[]` = 真的零張，語意分開、UI 呈現不同。新 iPhone 的 builder **永遠帶欄位**（零張給 `[]`）。
2. **不在 `CarrierClient` 內推送**：沿用 reactive 鏡像不變量（架構明文禁止 Client 內呼 bridge，避免 double-push）。載具異動靠 `context.save()` 自動觸發。
3. **排序沿用 iOS**：`listAll()` 回傳順序即 watch 顯示順序，watch 端不另做排序。
4. **條碼明文存 watch cache**：與 iPhone 端 widget 既有做法一致（App Group `CarrierEntryDTO` 已是明文），威脅模型相同，可接受。
5. **App Group 不跨裝置**：載具只能走 WatchConnectivity snapshot，無其他捷徑（這是 snapshot 擴充成為唯一合理路徑的原因）。
6. **模組邊界**：`WatchFeatures` 維持只依賴 TCA + Domain + Common（不依賴 Core）；`Carrier` / `CarrierType` 是純 Domain 型別，watch 直接 import。

## 5. Watch UI 結構

### 5.1 Root 組裝

- 新增 `WatchAppFeature` root reducer，`Scope` 組合既有 `WatchRecordFeature`（內部邏輯不動）與新 `WatchCarrierFeature`。
- Root view 為垂直 TabView（`.verticalPage`）：第 1 頁記帳（預設）、第 2 頁載具。
- **防誤滑**：記帳流程在「金額 / 確認」步驟時鎖定翻頁（只有分類步驟可上滑切頁）；載具頁任何時候可滑回。

### 5.2 載具頁四態（智慧快路徑）

| 狀態 | 畫面 |
|---|---|
| `carriers == nil` | 同步提示：icon +「資料同步中，請開啟 iPhone 上的 NeuLedger」 |
| `[]` | Empty 引導：條碼 icon +「尚無載具，請在 iPhone 上新增電子發票載具」 |
| 1 張 | **直接全螢幕條碼**（零點擊） |
| 2+ 張 | 列表（type icon + 名稱 + 文字碼小字），點列 push 進條碼頁 |

張數變化時（cache 更新）狀態自動重算。

### 5.3 條碼頁（直式滿版）

- 純白滿版底（`barcodeSurface`）、條碼轉 90° 吃滿螢幕高度（`barcodeInk`）
- 文字碼直排於條碼側（等寬字體、`monospacedDigit`），載具名稱小字
- AOD（`isLuminanceReduced`）時**條碼不打碼**、保持可見
- 編碼失敗（`Code128` 回 `nil`）→ 降級顯示大字文字碼

### 5.4 Design 規範遵循

- 顏色一律 `Color.Design`（新增 token 走 gateway，禁止 view 內硬編 `#FFFFFF`）
- 字體一律 `Font.Design`
- 字串一律 `String(localized:)`，放 watch target 的 `Localizable.xcstrings`，沿用 `watch_` 前綴
- Icon 用 SF Symbols（`barcode.viewfinder` 系列）

## 6. Code 128 編碼器（Common 層）

- **`Code128`**：純 Swift、零 import。字串 → 模組序列（`[Bool]`）。
  - 支援 **code set B + C 與數字串切換最佳化**（連續數字段切 code C、兩位數一碼）。自然人憑證「2 字母 + 14 數字」混編後 ~145 模組（純 B 要 211），模組寬度增 45%。
  - 含 mod 103 checksum、start/stop pattern、quiet zone。
  - 無法編碼的輸入（非 ASCII printable）回傳 `nil`。
- **`Code128BarcodeView`**：SwiftUI `Canvas` 繪製，支援方向參數（本功能用直式），向量縮放任意尺寸銳利。
- 放 Common 的理由：零依賴符合層規範；iOS app 與 widget 現有兩份重複的 file-private `CIFilter` 實作未來可改用此元件消債（follow-up，本次不動）。

## 7. 錯誤處理

| 情境 | 行為 |
|---|---|
| 編碼器回 `nil`（條碼含非法字元） | 條碼頁降級：只顯示大字文字碼（仍可手 key） |
| 舊 iPhone 推的 snapshot（無 carriers 欄位） | `nil` → 同步提示態 |
| 新 iPhone、真的零張 | `[]` → empty 引導態 |
| cache 解碼失敗 | 走既有 snapshot-nil 路徑 → 同步提示態 |
| WCSession 推送失敗 | 沿用既有「吞掉、WC 自行重試」語意，不變 |

## 8. 測試策略（Swift Testing）

1. **`Code128Tests`**（NeuLedgerTests；Common 跨平台、iOS host 可跑）：規格已知向量、checksum、B/C 切換邊界、quiet zone、非法輸入 → `nil`；兩個真實格式 case（`/AB12+CD`、`AB12345678901234`）。
2. **`WatchContextBuilderTests` 擴充**（既有 suite）：seed `CarrierStore` → snapshot 含 carriers 且順序同 `listAll()`；無載具 → `[]` 非 `nil`。
3. **`WatchCarrierFeatureTests`**（NeuLedgerWatchTests）：TestStore 驗四態切換、點列導航、cache 更新 reload。
4. **`WatchAppFeatureTests`**（NeuLedgerWatchTests）：Scope 組裝 + 翻頁鎖定邏輯。⚠️ TCA `Scope` 的 parent 測試會走到 child 依賴 — child path 的 closure 全部 stub（CLAUDE.md §10 血淚規則②）。
5. **`WatchCacheStoreTests` 擴充**：含 carriers 的 roundtrip + 舊 JSON（無 carriers key）仍可解碼且 `carriers == nil`（向後相容鐵證）。
6. **驗證跑法**：iOS 側 `NeuLedger` scheme 全量 + watch 側 `NeuLedgerWatchTests`（host-based，需 watchOS Simulator destination）。
7. **實機驗收**（無法自動化）：超商掃描器實測兩種載具條碼。若實測掃不到，後備方案為混合方向（依載具型別自動選向）。

## 9. 風險

| 風險 | 緩解 |
|---|---|
| 實體掃描器讀不到錶面條碼 | 直式 + B+C 混編將模組寬度最大化；文字碼常駐可手 key；實機驗收列入完成條件 |
| 自寫 Code 128 編碼錯誤 | 規格已知向量單元測試 + 與 iOS `CIFilter` 輸出交叉肉眼比對 |
| snapshot 加欄位破壞舊 watch 解碼 | 新欄位 optional；`WatchCacheStoreTests` 驗舊 JSON 相容 |
| 垂直翻頁與記帳流程手勢衝突 | 金額/確認步驟鎖定翻頁；`WatchAppFeatureTests` 驗鎖定邏輯 |
| watch schemes 未 shared、CI 不跑 watch 測試 | 本次驗證在本機跑 watch suite；scheme shared 化另議 |

## 10. Follow-ups（不在本次範圍）

- iOS app / widget 改用 `Code128BarcodeView` 取代兩份重複的 `CIFilter` `generateBarcode()`（消技術債）
- 載具 complication（錶面直達條碼）
- watch schemes shared 化讓 CI 跑 watch 測試
