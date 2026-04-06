# Widget 設計規格

**日期：** 2026-04-06
**功能：** iOS Home Screen Widgets — 我的載具 & 語音記帳

---

## 概覽

新增兩個獨立的 iOS Widget，讓使用者無需開啟 app 即可快速出示電子載具條碼、或以語音方式記帳。

| Widget | 尺寸 | 主要動作 |
|--------|------|----------|
| 我的載具（CarrierWidget） | Medium 2×1 | 顯示手機條碼/自然人憑證條碼供店員掃描 |
| 語音記帳（VoiceWidget） | Small 1×1 | 點按 → App Intent 背景錄音 → Live Activity 回饋 → 不需開啟 app |

---

## 架構

### Widget Extension

新增 **`NeuLedgerWidget`** Extension target（WidgetKit）。此 target 不依賴 `Features` SPM package，不直接存取 SwiftData。

```
NeuLedger.xcodeproj
├── NeuLedger (App target)
├── NeuLedgerWidget (Widget Extension target)
│   ├── CarrierWidget.swift
│   ├── VoiceWidget.swift
│   └── NeuLedgerWidgetBundle.swift
└── Shared/
    └── WidgetAppGroup.swift   ← 兩個 target 共用
```

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

    // 我的載具
    static var carrierBarcode: String      // 條碼字串，例如 /ABC1234
    static var carrierType: String         // CarrierType.rawValue
    static var carrierName: String         // 顯示名稱

    // 語音記帳
    static var voiceAccountId: String      // Account UUID
    static var voiceAccountName: String    // 帳戶顯示名稱
}
```

#### 對應的 SettingsKey 新增

在 `UserSettingsClient.swift` 新增（String 類型）：

| Key | rawValue | 說明 |
|-----|----------|------|
| `widgetCarrierId` | `"widgetCarrierId"` | 選中的 Carrier UUID |
| `widgetVoiceAccountId` | `"widgetVoiceAccountId"` | 語音記帳目標帳戶 UUID |

> `widgetCarrierBarcode`、`widgetCarrierType`、`widgetCarrierName`、`widgetVoiceAccountName` 為快取值，直接寫入 App Group UserDefaults（不需要 SettingsKey，因為 widget 不透過 UserSettingsClient 讀取）。

---

## Widget 1：我的載具（CarrierWidget）

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
- 條碼區：白色圓角背景，`Code128` barcode（使用 `CoreImage.CIFilter.code128BarcodeGenerator`）
- 色調：跟隨系統深/淺色模式

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

`widgetURL` deep link → 開啟 app 到 CarrierManagement 頁面

### Timeline

- `TimelineReloadPolicy.never`（資料不隨時間變化）
- 由主 app Settings 變更後主動呼叫 `WidgetCenter.shared.reloadTimelines(ofKind: "CarrierWidget")`

---

## Widget 2：語音記帳（VoiceWidget）

### 功能

點按 Widget → `StartVoiceRecordingIntent`（主 app target）背景執行錄音 → Live Activity 在 Dynamic Island 顯示即時狀態 → AI 辨識 → 寫入 SwiftData → 全程不需開啟 app。

### 尺寸

僅支援 **Small（`.systemSmall`）**。

### 視覺設計（四個狀態）

| 狀態 | 位置 | 視覺 |
|------|------|------|
| ① 待機 | Widget | 橙色圓形麥克風按鈕 + 帳戶名稱 |
| ③ 錄音中 | **Dynamic Island** | 音波動畫（橙色）+ 紅點閃爍 + 「錄音中」 |
| ④ AI 辨識中 | **Dynamic Island** | 跳動三點（橙色）+ 「AI 辨識中」 |
| ⑤ 記錄完成 | Widget | 綠色勾勾圓圈 + 「已記錄」（約 3 秒後 reload 回 ① 待機） |

> **WidgetKit 限制：** Widget 本身無法存取麥克風。`StartVoiceRecordingIntent` 定義於主 app target，由主 app 進程在背景執行錄音與 AI 辨識，透過 ActivityKit 推送 Live Activity 狀態至 Dynamic Island。

### App Intent

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

Widget 按鈕綁定：`Button(intent: StartVoiceRecordingIntent()) { ... }`

### Live Activity

```swift
struct VoiceRecordingAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var phase: Phase
        var recordingDuration: TimeInterval  // 已錄秒數（recording 階段持續更新）
        var transcribedText: String?         // 完成時的辨識摘要（例如「午餐 120 元」）
        var errorMessage: String?            // 錯誤訊息（僅 .failed 時有值）
        enum Phase: String, Codable { case recording, transcribing, done, failed }
    }
    var accountName: String
}
```

#### Dynamic Island 三種呈現模式

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

#### Lock Screen 呈現

鎖定畫面上以卡片形式顯示，佈局與 Expanded 類似：

```
┌──────────────────────────────────┐
│ [N icon]  NeuLedger     ● 錄音中 │
│  ▍▎▌▎▍▌▍▎▌▍   ← 音波 / 跳點     │
│  → 現金帳戶          0:05        │
└──────────────────────────────────┘
```

### 錄音停止機制

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

### 錯誤處理

| 場景 | 行為 |
|------|------|
| 麥克風權限未授予 | 不啟動 Live Activity，直接開啟 app Settings 提示授權 |
| 錄音失敗 | Live Activity 更新至 `.failed`（errorMessage: 「錄音失敗」），3 秒後 dismiss |
| Speech 轉文字失敗 | 同上，errorMessage: 「語音辨識失敗」 |
| Foundation Models 解析失敗 | 保存原始文字，開啟 app 讓使用者手動填入金額/分類 |
| App crash / 異常中斷 | Live Activity 設定 `staleDate`（啟動後 60 秒），超時系統自動移除 |

### 完成後 Widget 更新

1. `Activity.end(..., dismissalPolicy: .immediate)`
2. `WidgetCenter.shared.reloadTimelines(ofKind: "VoiceWidget")`
3. Widget timeline 切換至 ⑤ 完成狀態，3 秒後自動回到 ① 待機

### 目標帳戶顯示

從 App Group 讀取 `voiceAccountName`，顯示於麥克風按鈕下方。

---

## Settings 新增

在 `SettingsView` 新增「**Widget 設定**」Section，對應 `SettingsFeature` 的新 action：

### UI 結構

```
Widget 設定
├── 顯示的載具   [我的手機條碼 >]   ← Picker，從 carrierClient.fetchAll() 載入
└── 語音記帳帳戶 [現金帳戶 >]      ← Picker，從 accountClient.fetchActive() 載入
```

### SettingsFeature 新增 Action

```swift
case widgetCarrierSelected(Carrier.ID)
case widgetVoiceAccountSelected(Account.ID)
case widgetCarriersLoaded([Carrier])   // 若 carriers 尚未在 state 中
```

每次選擇後：
1. `userSettingsClient.setString(id, .widgetCarrierId)` （或 widgetVoiceAccountId）
2. 寫入 App Group UserDefaults（barcode、name、type 快取）
3. `WidgetCenter.shared.reloadAllTimelines()`

---

## Deep Link 處理

CarrierWidget 點擊時 deep link 開啟 app 至 CarrierManagement：

```
neuledger://carrier-management
```

`AppView` 在 `.onOpenURL` 解析並 dispatch 對應 action。VoiceWidget 全程透過 App Intent 背景執行，不需要 deep link。

---

## 新增檔案清單

| 檔案 | 位置 | 說明 |
|------|------|------|
| `NeuLedgerWidgetBundle.swift` | `NeuLedgerWidget/` | `@main WidgetBundle` |
| `CarrierWidget.swift` | `NeuLedgerWidget/` | 載具 widget TimelineProvider + View |
| `VoiceWidget.swift` | `NeuLedgerWidget/` | 語音 widget TimelineProvider + View + AppIntent |
| `WidgetAppGroup.swift` | `Shared/` | App Group UserDefaults 讀寫 helper（兩 target 共用）|
| `StartVoiceRecordingIntent.swift` | `NeuLedger/` (主 app target) | App Intent：背景錄音 + Live Activity 控制 |
| `StopVoiceRecordingIntent.swift` | `NeuLedger/` (主 app target) | App Intent：停止錄音觸發辨識 |
| `VoiceRecordingAttributes.swift` | `Shared/` | `ActivityAttributes` struct（主 app + Widget Extension 共用）|

### 修改的現有檔案

| 檔案 | 修改內容 |
|------|----------|
| `UserSettingsClient.swift` | 新增 `widgetCarrierId`、`widgetVoiceAccountId` SettingsKey |
| `SettingsFeature.swift` | 新增 Widget 設定 actions、寫入 App Group、reload timelines |
| `SettingsView.swift` | 新增 Widget 設定 Section |
| `AppFeature.swift` | 新增 `onOpenURL` handler（處理 carrier-management deep link）|
| `NeuLedger.entitlements` | 新增 App Group entitlement |
| `NeuLedger.xcodeproj` | 新增 Widget Extension target、App Group capability |
| `Info.plist` | 新增 `NSSupportsLiveActivities = YES`、`NSMicrophoneUsageDescription`、`UIBackgroundModes` 加入 `audio` |
| `NeuLedgerWidget.entitlements` | Widget Extension 新增同樣的 App Group entitlement |

---

## 測試要點

- `CarrierWidget`：App Group 空值 → 顯示提示；有值 → 正確渲染條碼
- `VoiceWidget`：點按 → App Intent 背景錄音 → Live Activity 正確顯示於 Dynamic Island；辨識完成後 widget reload 至 ⑤
- Live Activity：三種 DI 模式（compact / expanded / minimal）均正確渲染；Lock Screen 卡片正確顯示
- 錄音停止：使用者點按停止、靜音偵測、30 秒超時 — 三種方式均正確觸發辨識流程
- 錯誤處理：麥克風權限拒絕 → 提示授權；錄音/辨識失敗 → Live Activity 顯示錯誤後 dismiss；staleDate 超時 → 系統自動移除
- Settings：選擇載具/帳戶 → App Group 寫入正確 → Widget 即時更新
- 無載具/無帳戶時 Settings UI 的 disabled/empty 狀態
