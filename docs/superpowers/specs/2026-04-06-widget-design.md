# Widget 設計規格

**日期：** 2026-04-06
**功能：** iOS Home Screen Widgets — 我的載具 & 語音記帳

---

## 交付階段

| 階段 | 範圍 | 狀態 |
|------|------|------|
| **Phase 1**（本期） | CarrierWidget 上線 + VoiceWidget scaffolding（不對外開放） | 🔵 執行中 |
| **Phase 2**（待定） | VoiceWidget 完整啟用（App Intent 背景錄音 + Live Activity + AI 辨識） | ⏳ 待 Apple 背景錄音支援成熟後啟動 |

---

## 概覽

| Widget | 尺寸 | 主要動作 | 階段 |
|--------|------|----------|------|
| 我的載具（CarrierWidget） | Medium 2×1 | 顯示手機條碼/自然人憑證條碼供店員掃描 | Phase 1 |
| 語音記帳（VoiceWidget） | Small 1×1 | 點按 → App Intent 背景錄音 → Live Activity 回饋 | Phase 2 |

---

# Phase 1：CarrierWidget + Widget 基礎建設

## 架構

### Widget Extension

新增 **`NeuLedgerWidget`** Extension target（WidgetKit）。此 target 不依賴 `Features` SPM package，不直接存取 SwiftData。

```
NeuLedger.xcodeproj
├── NeuLedger (App target)
├── NeuLedgerWidget (Widget Extension target)
│   ├── CarrierWidget.swift
│   ├── VoiceWidget.swift         ← 保留程式碼，但不註冊進 WidgetBundle
│   └── NeuLedgerWidgetBundle.swift
└── Shared/
    └── WidgetAppGroup.swift      ← 兩個 target 共用
```

### VoiceWidget Gating

VoiceWidget 程式碼保留於 Extension target 內，但 **不註冊進 `WidgetBundle`**：

```swift
@main
struct NeuLedgerWidgetBundle: WidgetBundle {
    var body: some Widget {
        CarrierWidget()
        // VoiceWidget()  ← Phase 2 啟用時取消註解
    }
}
```

VoiceWidget 的 SwiftUI View 和 TimelineProvider 僅供 Xcode Preview 和 internal build 驗證使用。使用者在 widget picker 中看不到此 widget。

---

### 資料共享：App Group UserDefaults

主 app 與 Widget Extension 透過共享 App Group 交換設定資料。

- App Group ID：`group.app.neuledger`
- 主 app 在 Settings 變更時負責寫入，Widget 只讀
- 寫入後呼叫 `WidgetCenter.shared.reloadAllTimelines()`

#### 共享資料結構

```swift
// WidgetAppGroup.swift（放 Shared/ 目錄，兩個 target 均引用）
struct WidgetAppGroup {
    static let suiteName = "group.app.neuledger"

    // ── Phase 1：我的載具 ──
    static var carrierBarcode: String      // 條碼字串，例如 /ABC1234
    static var carrierType: String         // CarrierType.rawValue
    static var carrierName: String         // 顯示名稱
    static var carrierUpdatedAt: Date      // 最後寫入時間（快取失效判斷用）

    // ── Phase 2：語音記帳 ──
    // static var voiceAccountId: String
    // static var voiceAccountName: String
}
```

#### 快取失效策略

主 app 每次寫入 App Group 時一併更新 `carrierUpdatedAt`。Widget TimelineProvider 的 `getTimeline` 讀取時，若遇到以下情況顯示空值狀態：

| 場景 | 偵測方式 | Widget 行為 |
|------|----------|-------------|
| 未設定載具 | `carrierBarcode` 為空字串 | 顯示「請在 NeuLedger 設定 Widget 載具」 |
| 載具已在 app 中刪除 | 主 app 刪除載具時主動清空 App Group 並 reload timelines | 顯示空值狀態 |
| App Group 資料不一致 | `carrierBarcode` 有值但 `carrierType` 為空 | 視為無效，顯示空值狀態 |

主 app 端的寫入契約：

1. **Settings 選擇載具** → 寫入四欄（barcode / type / name / updatedAt）→ reload timelines
2. **CarrierManagement 刪除載具** → 若刪除的是 widget 使用中的載具 → 清空四欄 → reload timelines
3. **CarrierManagement 編輯載具** → 若編輯的是 widget 使用中的載具 → 更新四欄 → reload timelines

#### 對應的 SettingsKey 新增

在 `UserSettingsClient.swift` 新增（String 類型）：

| Key | rawValue | 說明 | 階段 |
|-----|----------|------|------|
| `widgetCarrierId` | `"widgetCarrierId"` | 選中的 Carrier UUID | Phase 1 |

> `widgetCarrierBarcode`、`widgetCarrierType`、`widgetCarrierName`、`widgetCarrierUpdatedAt` 為快取值，直接寫入 App Group UserDefaults（不需要 SettingsKey，因為 widget 不透過 UserSettingsClient 讀取）。

---

## CarrierWidget

### 功能

顯示使用者選定載具的條碼，讓店員直接掃描，免開 app。

### 尺寸

僅支援 **Medium（`.systemMedium`）**。條碼需要足夠寬度才能被掃描器讀取。

### 視覺設計

```
┌─────────────────────────────────────┐
│ [creditcard icon]  我的手機條碼  [手機條碼] │  ← 頂部列
│                                     │
│  ████ █ ███ █ ██ █ ███ ██ █ ██ ███  │  ← 白底條碼區，全寬
└─────────────────────────────────────┘
```

- 頂部：SF Symbol `creditcard.fill`（橙色）+ 載具名稱 + 類型 pill
- 條碼區：白色圓角背景，條碼佔滿整個寬度
- 色調：跟隨系統深/淺色模式

### 條碼產生

| 載具類型 | barcode 格式 | CIFilter | 說明 |
|----------|-------------|----------|------|
| `phoneBarcodeCarrier` | `/` + 7 碼大寫英數（e.g. `/ABC1234`） | `CICode128BarcodeGenerator` | Code 128 一維條碼 |
| `citizenDigitalCertificate` | 16 碼英數序號 | `CICode128BarcodeGenerator` | Code 128 一維條碼 |

產生流程：
1. 從 App Group 讀取 `carrierBarcode` 字串
2. 轉為 `Data(using: .ascii)`
3. 傳入 `CIFilter.code128BarcodeGenerator()` 的 `inputMessage`
4. 取得 `CIImage` → 放大（`CGAffineTransform(scaleX:y:)` 至足夠寬度）→ 轉為 `UIImage`
5. 在白色圓角背景上置中顯示，確保條碼兩側保留 quiet zone（至少 10x 模組寬度的空白）

> **Quiet zone 很重要**：沒有足夠的空白邊距，掃描器可能無法辨識條碼。

### 空值狀態

若 App Group 中未設定載具（`carrierBarcode` 為空）：
```
┌─────────────────────────────────────┐
│                                     │
│     請在 NeuLedger 設定 Widget 載具   │
│                                     │
└─────────────────────────────────────┘
```

### 點擊行為

`widgetURL` deep link → 開啟 app 到 CarrierManagement 頁面。

### Timeline

- `TimelineReloadPolicy.never`（資料不隨時間變化）
- 由主 app Settings / CarrierManagement 變更後主動呼叫 `WidgetCenter.shared.reloadTimelines(ofKind: "CarrierWidget")`

---

## Deep Link 處理

CarrierWidget 點擊時 deep link 開啟 app 至 CarrierManagement。

**URL scheme：** `neuledger://carrier-management`

**路由流程：**

1. `AppView` 的 `.onOpenURL` 接收 URL
2. Dispatch `AppFeature.Action.deepLinkReceived(url)`
3. `AppFeature` reducer 解析 URL path：
   - `carrier-management` → 確保 `destination == .main` → 切換到 Settings tab → push `.carrierManagement` 到 Settings navigation path
4. 若 app 尚未完成 onboarding，忽略 deep link（或排隊至 onboarding 完成後處理）

```swift
// AppFeature.swift
case let .deepLinkReceived(url):
    guard url.scheme == "neuledger",
          url.host == "carrier-management",
          state.destination == .main else { return .none }
    // 切換到 Settings tab 並 push CarrierManagement
    state.main?.selectedTab = .settings
    state.main?.settings.path.append(.carrierManagement(CarrierManagementFeature.State()))
    return .none
```

---

## Settings 新增

在 `SettingsView` 新增「**Widget 設定**」Section：

### UI 結構

```
Widget 設定
├── 顯示的載具   [我的手機條碼 >]   ← Picker，從 carrierClient.fetchAll() 載入
└── 語音記帳帳戶 [即將推出]         ← 靜態文字，灰色，不可點擊（Phase 2）
```

### State 新增

```swift
// SettingsFeature.State
var carriers: [Carrier] = []           // 已在現有 state 中？否則新增
var widgetCarrierId: String = ""       // 選中的 carrier UUID
var widgetCarrierName: String = ""     // 選中的 carrier 顯示名稱
```

### SettingsFeature 新增 Action

```swift
case widgetCarrierSelected(Carrier.ID)
case widgetCarriersLoaded([Carrier])
```

### 載入契約

`SettingsFeature.task` 中新增：
1. 讀取 `userSettingsClient.string(.widgetCarrierId)` → 設定 `widgetCarrierId`
2. 讀取 `carrierClient.fetchAll()` → 設定 `carriers` + 反查 `widgetCarrierName`

### 選擇後寫入

`widgetCarrierSelected` handler：
1. `userSettingsClient.setString(id, .widgetCarrierId)`
2. 從 `state.carriers` 取得對應 carrier
3. 寫入 App Group UserDefaults（barcode / type / name / updatedAt 四欄）
4. `WidgetCenter.shared.reloadTimelines(ofKind: "CarrierWidget")`

---

## Phase 1 新增檔案清單

| 檔案 | 位置 | 說明 |
|------|------|------|
| `NeuLedgerWidgetBundle.swift` | `NeuLedgerWidget/` | `@main WidgetBundle`（僅註冊 CarrierWidget）|
| `CarrierWidget.swift` | `NeuLedgerWidget/` | 載具 widget TimelineProvider + View |
| `VoiceWidget.swift` | `NeuLedgerWidget/` | 語音 widget scaffolding（不註冊，僅 Preview）|
| `WidgetAppGroup.swift` | `Shared/` | App Group UserDefaults 讀寫 helper（兩 target 共用）|

### Phase 1 修改的現有檔案

| 檔案 | 修改內容 |
|------|----------|
| `UserSettingsClient.swift` | 新增 `widgetCarrierId` SettingsKey |
| `SettingsFeature.swift` | 新增 Widget 設定 state / actions、App Group 寫入、reload timelines |
| `SettingsView.swift` | 新增 Widget 設定 Section（載具 Picker + 語音記帳「即將推出」） |
| `AppFeature.swift` | 新增 `deepLinkReceived` action、`.onOpenURL` handler |
| `CarrierManagementFeature.swift` | 刪除/編輯載具時同步清除或更新 App Group 快取 |
| `NeuLedger.entitlements` | 新增 App Group entitlement（`group.app.neuledger`）|
| `NeuLedgerWidget.entitlements` | Widget Extension 新增同樣的 App Group entitlement |
| `NeuLedger.xcodeproj` | 新增 Widget Extension target、App Group capability（雙 target）|

---

## Phase 1 測試要點

- **CarrierWidget 空值**：App Group 未設定 → 顯示提示文字
- **CarrierWidget 正常**：App Group 有值 → 正確渲染 Code 128 條碼（quiet zone 充足）
- **條碼可掃描**：使用實機 + 掃描器（或另一台手機的掃描 app）驗證條碼可被正確讀取
- **Settings 選擇載具**：選擇後 App Group 寫入正確 → Widget 即時更新
- **載具刪除同步**：在 CarrierManagement 刪除 widget 使用中的載具 → Widget 回到空值狀態
- **載具編輯同步**：在 CarrierManagement 修改 widget 使用中的載具 barcode → Widget 即時更新
- **Deep link**：點擊 Widget → app 開啟至 CarrierManagement（已完成 onboarding 時）
- **Deep link（未 onboarding）**：app 仍在 onboarding → deep link 被忽略
- **無載具時 Settings UI**：carriers 為空 → Widget 載具 Picker disabled 或顯示提示
- **語音記帳列**：顯示「即將推出」，不可操作

---

# Phase 2：VoiceWidget 完整啟用（待定）

> 以下內容為設計規劃，不在 Phase 1 交付範圍內。待 Apple 背景錄音支援（App Intent + AVAudioRecorder）在 iOS 26 正式確認後啟動。

## 啟用步驟

1. `NeuLedgerWidgetBundle` 取消 `VoiceWidget()` 註解
2. `WidgetAppGroup` 取消 `voiceAccountId` / `voiceAccountName` 註解
3. `UserSettingsClient` 新增 `widgetVoiceAccountId` SettingsKey
4. Settings 的「語音記帳帳戶」改為可操作的 Picker
5. 實作 `StartVoiceRecordingIntent` + `StopVoiceRecordingIntent` + Live Activity

## 功能

點按 Widget → `StartVoiceRecordingIntent`（主 app target）背景執行錄音 → Live Activity 在 Dynamic Island 顯示即時狀態 → AI 辨識 → 寫入 SwiftData → 全程不需開啟 app。

## 視覺設計（四個狀態）

| 狀態 | 位置 | 視覺 |
|------|------|------|
| ① 待機 | Widget | 橙色圓形麥克風按鈕 + 帳戶名稱 |
| ③ 錄音中 | **Dynamic Island** | 音波動畫（橙色）+ 紅點閃爍 + 「錄音中」 |
| ④ AI 辨識中 | **Dynamic Island** | 跳動三點（橙色）+ 「AI 辨識中」 |
| ⑤ 記錄完成 | Widget | 綠色勾勾圓圈 + 「已記錄」（約 3 秒後 reload 回 ① 待機） |

## App Intent

```swift
// 定義於主 app target（非 Widget Extension）
struct StartVoiceRecordingIntent: AppIntent {
    static var title: LocalizedStringResource = "開始語音記帳"

    func perform() async throws -> some IntentResult {
        // 1. 啟動 Live Activity（VoiceRecordingAttributes, phase: .recording）
        // 2. 錄音（AVAudioRecorder）
        // 3. Speech framework 轉文字
        // 4. Foundation Models 解析金額/分類
        // 5. 寫入 SwiftData
        // 6. 更新 Live Activity phase → .done → dismiss
        // 7. WidgetCenter.reloadTimelines(ofKind: "VoiceWidget")
        return .result()
    }
}
```

## Live Activity

```swift
struct VoiceRecordingAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var phase: Phase
        var recordingDuration: TimeInterval
        var transcribedText: String?
        var errorMessage: String?
        enum Phase: String, Codable { case recording, transcribing, done, failed }
    }
    var accountName: String
}
```

### Dynamic Island 三種呈現模式

**Compact（預設，leading + trailing）：**

```
┌─ leading ──┬── trailing ─┐
│ 🎙 (橙色)  │  0:03 (秒數) │    ← recording
│ ●●● (跳點)│  辨識中      │    ← transcribing
└────────────┴─────────────┘
```

**Expanded（使用者長按 DI 展開）：**

```
┌──────────── expanded ─────────────┐
│  leading:  🎙 mic icon             │
│  center:   音波動畫 / 跳動三點       │
│  trailing: 0:05                    │
│  bottom:   「現金帳戶」 · 點按停止    │
└───────────────────────────────────┘
```

- `.recording` → center 顯示音波動畫，bottom 顯示帳戶名 + 「點按停止」
- `.transcribing` → center 顯示跳動三點，bottom 顯示「AI 辨識中…」
- `.done` → center 顯示 ✓，bottom 顯示辨識摘要（transcribedText）
- `.failed` → center 顯示 ✕，bottom 顯示 errorMessage

**Minimal（有其他 Live Activity 同時運行時）：**

DI 另一側顯示橙色小圓圈。`.recording` 時圓圈脈衝，`.transcribing` 時靜態。

### Lock Screen 呈現

鎖定畫面上以卡片形式顯示：

```
┌──────────────────────────────────┐
│ [N icon]  NeuLedger     ● 錄音中 │
│  ▍▎▌▎▍▌▍▎▌▍   ← 音波 / 跳點     │
│  → 現金帳戶          0:05        │
└──────────────────────────────────┘
```

## 錄音停止機制

錄音透過以下三種方式之一停止（先觸發者為準）：

1. **使用者點擊 Dynamic Island expanded → 「點按停止」** — 觸發 `StopVoiceRecordingIntent`
2. **靜音偵測** — 連續 2 秒音量低於閾值自動停止
3. **最長時限** — 30 秒自動停止（避免忘記關閉）

```swift
struct StopVoiceRecordingIntent: AppIntent {
    static var title: LocalizedStringResource = "停止語音記帳"

    func perform() async throws -> some IntentResult {
        // 通知錄音 session 停止，觸發 transcription 流程
        return .result()
    }
}
```

## 錯誤處理

| 場景 | 行為 |
|------|------|
| 麥克風權限未授予 | 不啟動 Live Activity，直接開啟 app Settings 提示授權 |
| 錄音失敗 | Live Activity 更新至 `.failed`（errorMessage: 「錄音失敗」），3 秒後 dismiss |
| Speech 轉文字失敗 | 同上，errorMessage: 「語音辨識失敗」 |
| Foundation Models 解析失敗 | 保存原始文字，開啟 app 讓使用者手動填入金額/分類 |
| App crash / 異常中斷 | Live Activity 設定 `staleDate`（啟動後 60 秒），超時系統自動移除 |

## 完成後 Widget 更新

1. `Activity.end(..., dismissalPolicy: .immediate)`
2. `WidgetCenter.shared.reloadTimelines(ofKind: "VoiceWidget")`
3. Widget timeline 切換至 ⑤ 完成狀態，3 秒後自動回到 ① 待機

## Phase 2 新增檔案

| 檔案 | 位置 | 說明 |
|------|------|------|
| `StartVoiceRecordingIntent.swift` | `NeuLedger/` (主 app target) | App Intent：背景錄音 + Live Activity 控制 |
| `StopVoiceRecordingIntent.swift` | `NeuLedger/` (主 app target) | App Intent：停止錄音觸發辨識 |
| `VoiceRecordingAttributes.swift` | `Shared/` | `ActivityAttributes` struct（主 app + Widget Extension 共用）|

## Phase 2 修改的現有檔案

| 檔案 | 修改內容 |
|------|----------|
| `NeuLedgerWidgetBundle.swift` | 取消 `VoiceWidget()` 註解 |
| `WidgetAppGroup.swift` | 取消 voiceAccountId / voiceAccountName 註解 |
| `UserSettingsClient.swift` | 新增 `widgetVoiceAccountId` SettingsKey |
| `SettingsFeature.swift` | 新增 `widgetVoiceAccountSelected` action、voice account App Group 寫入 |
| `SettingsView.swift` | 語音記帳帳戶列改為可操作 Picker |
| `Info.plist` | 新增 `NSSupportsLiveActivities = YES`、`NSMicrophoneUsageDescription`、`UIBackgroundModes: audio` |

## Phase 2 測試要點

- VoiceWidget：點按 → App Intent 背景錄音 → Live Activity 正確顯示於 Dynamic Island；辨識完成後 widget reload 至 ⑤
- Live Activity：三種 DI 模式（compact / expanded / minimal）均正確渲染；Lock Screen 卡片正確顯示
- 錄音停止：使用者點按停止、靜音偵測、30 秒超時 — 三種方式均正確觸發辨識流程
- 錯誤處理：麥克風權限拒絕 → 提示授權；錄音/辨識失敗 → Live Activity 顯示錯誤後 dismiss；staleDate 超時 → 系統自動移除
- Settings：語音記帳帳戶 Picker 可選擇 → App Group 寫入正確
