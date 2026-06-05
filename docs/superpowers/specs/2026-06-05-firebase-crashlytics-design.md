# Firebase Crashlytics 導入設計

**日期**：2026-06-05
**狀態**：✅ 設計核可，待實作
**分支**：`feature/firebase-crashlytics`（基於 `developer` @ `033b219`）

---

## 1. 目標與範圍

為 NeuLedger 導入 Firebase Crashlytics 崩潰回報，含手動記錄 non-fatal 錯誤的能力。

**範圍內**：

1. 自動崩潰收集 — 只限 **iOS app target**，Release-only（DEBUG 停用收集）
2. Non-fatal 記錄能力 — `platformClient` 新增 `recordError`，Features 層可記錄捕到的錯誤
3. dSYM 上傳 — Xcode Cloud `ci_post_xcodebuild.sh`，archive build 自動上傳

**非目標**：

- Watch App / Widget / Watch Complication targets（之後有需要再加）
- Firebase Analytics 或其他 Firebase 服務
- 改既有 reducer 去呼叫 `recordError`（能力就緒，呼叫點按需逐步加）
- 本地 archive 的 dSYM 上傳（發布路徑只走 Xcode Cloud）

**前置條件（已完成）**：Firebase 專案 `neuledger` 已建立、iOS app 已註冊（`com.drake.NeuLedger`）、`GoogleService-Info.plist` 已取得（`~/Downloads/GoogleService-Info.plist`，內容已驗證 BUNDLE_ID 相符、Analytics disabled）。

## 2. 方案決策

評估過三個方案，採 **方案 A：Client + Bootstrap**：

| 方案 | 內容 | 裁定 |
|---|---|---|
| **A. Client + Bootstrap** | Firebase 只掛 Core SPM target；初始化走 `CrashReportingBootstrap`（比照 `WatchBootstrap` 慣例）；non-fatal 走 `platformClient.recordError` | ✅ 採用 — 完全符合分層紀律，Features 層零 Firebase import |
| B. Features 直接接 SDK | `AppView` import FirebaseCore、reducer import FirebaseCrashlytics | ❌ 違反「Features 只透過 Client 碰外界」；reducer 呼叫無法被 TestStore stub |
| C. 獨立 CrashReporterClient | 新開第七個 client | ❌ 違反 CLAUDE.md client 增設規則；crash reporting 屬 platformClient「App 自身的運行環境」職責 |

## 3. 架構與元件

```
┌─ NeuLedger app target ───────────────────────────────────┐
│  NeuLedger/Resources/GoogleService-Info.plist（git-ignored，注入式 §3.4）│
│  NeuLedger/Info.plist ── 加 FirebaseCrashlyticsCollectionEnabled=NO │
└───────────────────────────────────────────────────────────┘
Features/Sources/
├── Features/AppView.swift          ── init() 加 CrashReportingBootstrap.start()
├── Domain/Clients/PlatformClient.swift ── System 區段新增 recordError closure
├── Application/Platform/PlatformClient+Live.swift ── recordError live 實作
└── Core/Adapters/CrashReporting/CrashReportingBootstrap.swift（新檔）
ci_scripts/ci_post_xcodebuild.sh（新檔）── archive 後上傳 dSYM
```

### 3.1 SPM 依賴

`Features/Package.swift`：

- `dependencies` 加 `.package(url: "https://github.com/firebase/firebase-ios-sdk", from: "12.14.0")`（查核時的最新穩定版；實際解析版本由 `Package.resolved` 鎖定）
- `Core` target 加 `.product(name: "FirebaseCrashlytics", package: "firebase-ios-sdk")`

**只掛 `Core` target**。`WatchFeatures` 不依賴 Core（Package.swift 既有註解明載），所以 Watch / Widget 不會連結 Firebase——自然達成「只要 iOS app」的範圍限制。

### 3.2 CrashReportingBootstrap（新檔）

`Features/Sources/Core/Adapters/CrashReporting/CrashReportingBootstrap.swift`，完全比照 `WatchBootstrap` 慣例（`@MainActor enum`、冪等、composition root 由 `App.init()` 呼叫）：

```swift
import Foundation
import FirebaseCore
import FirebaseCrashlytics

@MainActor
public enum CrashReportingBootstrap {
    private static var started = false

    public static func start() {
        guard !started else { return }
        started = true
        // plist 為注入式（見 §3.4）：bundle 內缺檔 → 靜默停用 crash
        // reporting，不讓 FirebaseApp.configure() crash on launch
        guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else {
            return
        }
        FirebaseApp.configure()
        #if !DEBUG
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
        #endif
    }
}
```

`AppView.init()` 在 `WatchBootstrap.start()` **之前**加一行 `CrashReportingBootstrap.start()`（`FirebaseApp.configure()` 應為 process 啟動後最早的初始化；`Core` 已在 import 清單，Features 層不需 import Firebase）。

### 3.3 PlatformClient 擴充

`Domain/Clients/PlatformClient.swift` System 區段新增（Domain 介面零 Firebase 型別）：

```swift
/// Records a non-fatal error to the crash-reporting backend.
/// Fire-and-forget — call sites do not await.
public var recordError: @Sendable (_ error: any Error, _ userInfo: [String: String]) -> Void
```

`Application/Platform/PlatformClient+Live.swift` 加 `import FirebaseCrashlytics`，live 實作轉呼叫 `Crashlytics.crashlytics().record(error:userInfo:)`。

### 3.4 GoogleService-Info.plist（注入式，2026-06-05 改版）

> 原設計為 commit 進 repo（Firebase 官方標準做法），但本 repo 為 **public**，改採注入模型。歷史已重寫，plist 不在任何 commit 中。

- 路徑仍為 `NeuLedger/Resources/GoogleService-Info.plist`（synchronized folder，檔案存在即入 bundle），但**永不 commit**——已加入 `.gitignore`
- **本地開發**：手動放置一份在該路徑（不放也能跑，見 §5 guard）
- **Xcode Cloud**：三個 workflow 各設 secret 環境變數 `GOOGLE_SERVICE_INFO_PLIST_B64`（plist 內容的 base64），`ci_scripts/ci_post_clone.sh` 解碼寫檔
- 已公開暴露的 API key：PR #16（已關閉）的 commit 在 GitHub 仍可達——應在 Google Cloud Console 對該 key 加 iOS app（bundle ID `com.drake.NeuLedger`）限制

### 3.5 DEBUG 停用收集

- `NeuLedger/Info.plist` 加 `FirebaseCrashlyticsCollectionEnabled = NO`（預設關）
- Release 由 bootstrap 的 `#if !DEBUG` 分支以 `setCrashlyticsCollectionEnabled(true)` 開啟
- dashboard 只會有真實使用者（TestFlight / App Store build）的崩潰

## 4. 資料流

- **崩潰（自動）**：app 崩潰 → 下次啟動 `FirebaseApp.configure()` 時 Crashlytics 撈起上次 crash report → 上傳 Firebase。
- **Non-fatal（手動）**：reducer → `@Dependency(\.platformClient).recordError(error, userInfo)` → live 轉 `Crashlytics.record(error:userInfo:)`。fire-and-forget、不 await、不 throw——記錄失敗絕不影響業務流程。DEBUG 下收集停用，SDK 自行丟棄，呼叫端不需判斷。

## 5. 錯誤處理

- plist 缺失時 `FirebaseApp.configure()` 會 crash on launch —— bootstrap 以 `Bundle.main.path(forResource:ofType:)` guard：缺檔（新 clone、未設 secret 的 CI）→ 靜默跳過 configure，app 照常運行、crash reporting 停用。PR workflow 的模擬器測試會啟動 app，此 guard 是測試不掛的前提
- TestFlight/Release workflow 若忘設 `GOOGLE_SERVICE_INFO_PLIST_B64`：app 可建置，但 `ci_post_xcodebuild.sh` 的 `-gsp` 找不到檔案會讓 build fail——**刻意 fail loud**，避免靜默出貨一個沒有崩潰回報的版本
- `recordError` 簽名無 `throws`、無回傳值，呼叫端零錯誤處理負擔；plist 未注入時 Crashlytics 未 configure，呼叫為 no-op（SDK 容忍）

## 6. dSYM 上傳（Xcode Cloud）

新增 `ci_scripts/ci_post_xcodebuild.sh`：

```sh
#!/bin/sh
# Upload dSYMs to Firebase Crashlytics after archive builds only.
if [ -n "$CI_ARCHIVE_PATH" ]; then
  "$CI_DERIVED_DATA_PATH/SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/upload-symbols" \
    -gsp "$CI_PRIMARY_REPOSITORY_PATH/NeuLedger/Resources/GoogleService-Info.plist" \
    -p ios "$CI_ARCHIVE_PATH/dSYMs"
fi
```

- 只在 TestFlight / Release workflow（有 archive）執行；PR workflow 的 `CI_ARCHIVE_PATH` 為空，自動跳過
- `upload-symbols` 直接用 SPM checkout 內建的，不需額外安裝
- 實作時順帶確認 Release 組態 `DEBUG_INFORMATION_FORMAT = dwarf-with-dsym`（Xcode 預設即是）

## 7. 測試策略

- **Domain 測試**：比照既有慣例，驗證 `platformClient` 經 `DependencyValues` key path 可取用；既有 `PlatformClient` domain 測試若列舉 closure，補 `recordError`
- **Feature 測試**：本次不改任何 reducer → 既有測試不受影響（`testValue = Self()` 慣例下，沒碰到的 closure 不需 stub）
- **Bootstrap 不寫單元測試**：`FirebaseApp.configure()` 無法在測試環境驗證，比照 `WatchBootstrap` 無測試的先例
- **最終驗證**：build app + 跑完整 `NeuLedger` test scheme

## 8. 使用者後續行動（非本次程式碼範圍）

- **App Store Connect → Xcode Cloud：三個 workflow（PR / TestFlight / Release）的 Environment Variables 各加 `GOOGLE_SERVICE_INFO_PLIST_B64`（勾選 Secret）**，值為 plist 的 base64（產生指令：`base64 -i ~/Downloads/GoogleService-Info.plist | pbcopy`）
- Google Cloud Console → 對外洩過的 API key 加 iOS app 限制（bundle ID `com.drake.NeuLedger`）
- App Store Connect → App Privacy 申報「崩潰資料」收集（Firebase SDK 已內建 privacy manifest，build 端不用動）
- 上 TestFlight 後在 Firebase Console 確認首批 dSYM 與崩潰回報進得來
