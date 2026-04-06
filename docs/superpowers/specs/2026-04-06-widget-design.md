# Widget 設計規格

**日期：** 2026-04-06
**功能：** iOS Home Screen Widgets — 我的載具 & 語音記帳

---

## 概覽

新增兩個獨立的 iOS Widget，讓使用者無需開啟 app 即可快速出示電子載具條碼、或以語音方式記帳。

| Widget | 尺寸 | 主要動作 |
|--------|------|----------|
| 我的載具（CarrierWidget） | Medium 2×1 | 顯示手機條碼/自然人憑證條碼供店員掃描 |
| 語音記帳（VoiceWidget） | Small 1×1 | 長按 → 開啟 app 進行語音錄音與 AI 記帳 |

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

長按麥克風按鈕 → 觸發 App Intent → 開啟 app 進入語音錄音畫面 → AI 辨識 → 記帳至指定帳戶。

### 尺寸

僅支援 **Small（`.systemSmall`）**。

### 視覺設計（五個狀態）

| 狀態 | 位置 | 視覺 |
|------|------|------|
| ① 待機 | Widget | 橙色圓形麥克風按鈕 + 帳戶名稱 + 「點按開始錄音」提示 |
| ② 啟動感應 | Widget | 按鈕外圈脈衝環動畫 + 「準備中…」（App Intent perform 期間的 optimistic UI）|
| ③ 錄音中 | **App 內** | 音波動畫 + 紅點閃爍 + 「錄音中」 |
| ④ AI 辨識中 | **App 內** | 跳動三點 + 「辨識中…」 |
| ⑤ 記錄完成 | Widget | 綠色勾勾圓圈 + 「已記錄」（顯示約 3 秒後 reload 回 ① 待機） |

> **手勢說明：** WidgetKit 標準僅支援 `Button` tap（不支援長按手勢）。① → ② 由普通點按觸發 App Intent，② 的動畫是 SwiftUI `invalidatableContent()` 在 intent perform 期間的過渡視覺，隨後 app 開啟並進入 ③。「防誤觸」需求由 app 內的錄音畫面自行設計（例如顯示 1 秒倒數再開始）。
>
> Widget 本身（WidgetKit 沙箱）無法存取麥克風，③④ 必須在主 app 內執行。

### App Intent

```swift
struct StartVoiceRecordingIntent: AppIntent {
    static var title: LocalizedStringResource = "開始語音記帳"

    func perform() async throws -> some IntentResult & OpensIntent {
        // Deep link 至 app 的 VoiceRecording destination
        return .result(opensIntent: OpenURLIntent(voiceRecordingDeepLink))
    }
}
```

Widget 按鈕綁定：`Button(intent: StartVoiceRecordingIntent()) { ... }`（iOS 17+ interactive widget）

### 完成後 Widget 更新

主 app 記帳成功後：
1. 寫入 App Group（可選：記錄最後記帳時間）
2. 呼叫 `WidgetCenter.shared.reloadTimelines(ofKind: "VoiceWidget")`
3. Widget timeline 切換至 ⑤ 完成狀態（顯示 3 秒後回到 ① 待機）

### 目標帳戶顯示

從 App Group 讀取 `voiceAccountName`，顯示於按鈕下方。

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

`AppFeature.Destination` 新增：

```swift
case voiceRecording(targetAccountId: String)
```

URL scheme：`neuledger://voice-recording?accountId=<uuid>`

`AppView` 在 `.onOpenURL` 解析並 dispatch 對應 action。

---

## 新增檔案清單

| 檔案 | 位置 | 說明 |
|------|------|------|
| `NeuLedgerWidgetBundle.swift` | `NeuLedgerWidget/` | `@main WidgetBundle` |
| `CarrierWidget.swift` | `NeuLedgerWidget/` | 載具 widget TimelineProvider + View |
| `VoiceWidget.swift` | `NeuLedgerWidget/` | 語音 widget TimelineProvider + View + AppIntent |
| `WidgetAppGroup.swift` | `Shared/` | App Group UserDefaults 讀寫 helper（兩 target 共用）|

### 修改的現有檔案

| 檔案 | 修改內容 |
|------|----------|
| `UserSettingsClient.swift` | 新增 `widgetCarrierId`、`widgetVoiceAccountId` SettingsKey |
| `SettingsFeature.swift` | 新增 Widget 設定 actions、寫入 App Group、reload timelines |
| `SettingsView.swift` | 新增 Widget 設定 Section |
| `AppFeature.swift` | 新增 `voiceRecording` destination、`onOpenURL` handler |
| `NeuLedger.entitlements` | 新增 App Group entitlement |
| `NeuLedger.xcodeproj` | 新增 Widget Extension target、App Group capability |

---

## 測試要點

- `CarrierWidget`：App Group 空值 → 顯示提示；有值 → 正確渲染條碼
- `VoiceWidget`：Long press intent → app 正確開啟至語音錄音畫面；完成後 timeline reload
- Settings：選擇載具/帳戶 → App Group 寫入正確 → Widget 即時更新
- 無載具/無帳戶時 Settings UI 的 disabled/empty 狀態
