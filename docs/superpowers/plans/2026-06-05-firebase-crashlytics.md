# Firebase Crashlytics 導入 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 為 iOS app 導入 Firebase Crashlytics（Release-only 自動崩潰收集 + `platformClient.recordError` non-fatal 記錄 + Xcode Cloud dSYM 上傳）。

**Architecture:** Firebase SDK 只掛 SPM `Core` target；初始化走新的 `CrashReportingBootstrap`（比照 `WatchBootstrap` 慣例，由 `AppView.init()` 呼叫）；non-fatal 記錄歸入 `platformClient` System 區段。Features 層零 Firebase import。

**Tech Stack:** firebase-ios-sdk 12.14.0+（SPM）、TCA `@DependencyClient`、Swift Testing、Xcode Cloud ci_scripts。

**Spec:** `docs/superpowers/specs/2026-06-05-firebase-crashlytics-design.md`

**執行環境:** worktree `/Users/drakehuang/SideProject/iOSProject/NeuLedger/.claude/worktrees/firebase-crashlytics`，分支 `feature/firebase-crashlytics`。所有指令在此目錄執行。

---

## Target / Module Boundary（先讀，避免繞路）

| 路徑 | 所屬 target | Firebase import 權限 |
|---|---|---|
| `Features/Sources/Domain/**` | SPM `Domain` | ❌ 零外部 import（只有 Dependencies/DependenciesMacros/CasePaths） |
| `Features/Sources/Core/**`、`Features/Sources/Application/**` | SPM `Core`（同一 target，Package.swift `sources: ["Core", "Application"]`） | ✅ Task 1 之後可 `import FirebaseCore` / `FirebaseCrashlytics` |
| `Features/Sources/Features/**` | SPM `Features` | ❌ 不准 import Firebase。`CrashReportingBootstrap` 是 `Core` 的 public 型別，`AppView.swift` 已 `import Core`，直接呼叫即可 |
| `NeuLedger/**` | xcodeproj app target（`PBXFileSystemSynchronizedRootGroup`：檔案放進資料夾即自動入 target，**不需改 pbxproj**） | n/a（資源與 Info.plist） |
| `NeuLedgerTests/**` | xcodeproj test target | 測試 `@testable import Domain` |
| `ci_scripts/**` | 無 target（Xcode Cloud shell hooks） | n/a |

已查證、不需做的事：

- Release 組態 `DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym"` 已是專案預設（pbxproj 行 1069）——**不用動**
- `WatchFeatures` 不依賴 `Core`（Package.swift 註解明載）——Firebase 不會連進 Watch/Widget，**不用做任何排除**
- `GoogleService-Info.plist` 已驗證 `BUNDLE_ID = com.drake.NeuLedger`、`IS_ANALYTICS_ENABLED = false`，與 app target 的 `PRODUCT_BUNDLE_IDENTIFIER` 一致

---

### Task 1: SPM 依賴接入

**Files:**
- Modify: `Features/Package.swift`
- 副產物: `NeuLedger.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`（resolve 自動更新，一併 commit）

- [ ] **Step 1.1: 在 `Features/Package.swift` 的 `dependencies` 陣列加入 firebase-ios-sdk**

在 `.package(url: "https://github.com/pointfreeco/swift-case-paths", ...)` 區塊之後加：

```swift
        .package(
            url: "https://github.com/firebase/firebase-ios-sdk",
            from: "12.14.0"
        ),
```

- [ ] **Step 1.2: 把 `FirebaseCrashlytics` product 掛上 `Core` target**

`Core` target 宣告改為（只新增 `.firebaseCrashlytics` 一行）：

```swift
        .target(
            name: "Core",
            dependencies: [
                "Domain",
                .dependencies,
                .firebaseCrashlytics,
            ],
```

並在檔尾 `extension Target.Dependency` 區塊（`casePaths` 之後）加 helper：

```swift
    static let firebaseCrashlytics: Target.Dependency = .product(
        name: "FirebaseCrashlytics",
        package: "firebase-ios-sdk"
    )
```

- [ ] **Step 1.3: 解析套件**

Run（首次下載 Firebase，需數分鐘，建議 `run_in_background`）:

```bash
xcodebuild -resolvePackageDependencies -project NeuLedger.xcodeproj -scheme NeuLedger
```

Expected: 結尾出現 `resolved source packages` 清單，包含 `firebase-ios-sdk @ 12.x` 與傳遞依賴（GoogleUtilities、GoogleDataTransport、nanopb、Promises 等）。`git status` 顯示 `Package.resolved` 有變更。

- [ ] **Step 1.4: Commit**

```bash
git add Features/Package.swift NeuLedger.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
git commit -m "feat(core): add firebase-ios-sdk dependency for crashlytics [ci skip]"
```

---

### Task 2: Domain — `platformClient.recordError`（TDD）

**Files:**
- Test: `NeuLedgerTests/Tests/DomainTests/Clients/PlatformClientTests.swift`（System 區段，`testOpenAppSettingsMock` 之後）
- Modify: `Features/Sources/Domain/Clients/PlatformClient.swift`（System 區段，`openAppSettings` 之後、struct 結尾 `}` 之前）

- [ ] **Step 2.1: 寫失敗測試**

在 `PlatformClientTests.swift` 的 `// MARK: - System` 區段、`testOpenAppSettingsMock()` 方法之後加入：

```swift
    @Test("recordError mock override")
    func testRecordErrorMock() {
        struct DummyError: Error {}
        withDependencies {
            $0.platformClient.recordError = { error, userInfo in
                #expect(error is DummyError)
                #expect(userInfo == ["screen": "dashboard"])
            }
        } operation: {
            @Dependency(\.platformClient) var client
            client.recordError(DummyError(), ["screen": "dashboard"])
        }
    }
```

- [ ] **Step 2.2: 跑測試，確認 red**

Run:

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:NeuLedgerTests/PlatformClientTests
```

Expected: **編譯失敗**（red 的形式是 compile error）：`value of type 'PlatformClient' has no member 'recordError'`。

- [ ] **Step 2.3: 在 Domain 介面加入 `recordError`**

`Features/Sources/Domain/Clients/PlatformClient.swift`，`openAppSettings` 宣告（`public var openAppSettings: @Sendable () -> Void`）之後加：

```swift

    /// Records a non-fatal error to the crash-reporting backend.
    /// Fire-and-forget — call sites do not await.
    public var recordError: @Sendable (_ error: any Error, _ userInfo: [String: String]) -> Void
```

說明：`@DependencyClient` 對 Void 回傳的 closure 自動生成 unimplemented stub，`testValue = Self()` 不需要改；既有測試沒碰到 `recordError` 不用補 stub。Domain 介面零 Firebase 型別（`any Error` + `[String: String]`）。

- [ ] **Step 2.4: 跑測試，確認 green**

Run（同 Step 2.2 指令）

Expected: `Test Suite 'PlatformClientTests' passed`，含新的 `recordError mock override`。

- [ ] **Step 2.5: Commit**

```bash
git add Features/Sources/Domain/Clients/PlatformClient.swift NeuLedgerTests/Tests/DomainTests/Clients/PlatformClientTests.swift
git commit -m "feat(domain): add recordError to PlatformClient [ci skip]"
```

---

### Task 3: Application — recordError live 實作

**Files:**
- Modify: `Features/Sources/Application/Platform/PlatformClient+Live.swift`

- [ ] **Step 3.1: 加 import**

在 `import SwiftData`（第 4 行）之後加：

```swift
import FirebaseCrashlytics
```

- [ ] **Step 3.2: 在 memberwise init 結尾補 `recordError` 引數**

`// MARK: System` 區段的 `openAppSettings` closure 是 init 的最後一個引數（檔案約第 183–191 行）。在其結尾 `}` 後加逗號與新引數（**引數順序必須跟 Domain 宣告順序一致，`recordError` 在 `openAppSettings` 之後**）：

```swift
            // MARK: System
            openAppSettings: {
                #if canImport(UIKit)
                Task { @MainActor in
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                #endif
            },
            recordError: { error, userInfo in
                Crashlytics.crashlytics().record(error: error, userInfo: userInfo)
            }
        )
```

- [ ] **Step 3.3: Build 驗證**

Run（首次編 Firebase，較久，建議 `run_in_background`）:

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Expected: `** BUILD SUCCEEDED **`。

- [ ] **Step 3.4: Commit**

```bash
git add Features/Sources/Application/Platform/PlatformClient+Live.swift
git commit -m "feat(application): wire recordError to Crashlytics in live PlatformClient [ci skip]"
```

---

### Task 4: Bootstrap + App 接線 + plist 資源

**Files:**
- Create: `Features/Sources/Core/Adapters/CrashReporting/CrashReportingBootstrap.swift`
- Modify: `Features/Sources/Features/AppView.swift:22-28`（`init()`）
- Create: `NeuLedger/Resources/GoogleService-Info.plist`（從 `~/Downloads` 複製）
- Modify: `NeuLedger/Info.plist`

- [ ] **Step 4.1: 建立 `CrashReportingBootstrap.swift`**

新檔 `Features/Sources/Core/Adapters/CrashReporting/CrashReportingBootstrap.swift`，完整內容：

```swift
import FirebaseCore
import FirebaseCrashlytics

/// Composition-root entry point for Firebase crash reporting.
///
/// Must be called once at process launch (i.e. `App.init()`), before any
/// other launch work — `FirebaseApp.configure()` is also the moment
/// Crashlytics picks up the previous run's crash report, so the earlier
/// the better.
///
/// Collection is disabled by default via the app target's Info.plist key
/// `FirebaseCrashlyticsCollectionEnabled = NO`; Release builds re-enable
/// it here so DEBUG crashes never pollute the dashboard.
///
/// Idempotent: repeated calls are no-ops.
@MainActor
public enum CrashReportingBootstrap {

    private static var started = false

    public static func start() {
        guard !started else { return }
        started = true

        FirebaseApp.configure()
        #if !DEBUG
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
        #endif
    }
}
```

- [ ] **Step 4.2: `AppView.init()` 接線**

`Features/Sources/Features/AppView.swift` 的 `init()` 改為（`CrashReportingBootstrap.start()` 在 `WatchBootstrap.start()` **之前**；不需新 import，`Core` 已在清單）：

```swift
    init() {
        // Composition Root: crash reporting first — `FirebaseApp.configure()`
        // must be the earliest launch work so Crashlytics can pick up the
        // previous run's crash report before anything else executes.
        CrashReportingBootstrap.start()
        // Composition Root: wire the Watch bridge before any UI exists so
        // background-delivered WatchConnectivity payloads are caught on
        // the very first delegate dispatch after launch.
        // TODO: Dependency injection
        WatchBootstrap.start()
    }
```

- [ ] **Step 4.3: 放入 GoogleService-Info.plist**

```bash
cp ~/Downloads/GoogleService-Info.plist NeuLedger/Resources/GoogleService-Info.plist
```

說明：`NeuLedger/` 是 `PBXFileSystemSynchronizedRootGroup`（例外清單只有 `Info.plist`），檔案放進資料夾即自動成為 app target 資源，**不要動 pbxproj**。

- [ ] **Step 4.4: `NeuLedger/Info.plist` 加停用收集 key**

在 `<key>ITSAppUsesNonExemptEncryption</key>` 那組之後加：

```xml
	<key>FirebaseCrashlyticsCollectionEnabled</key>
	<false/>
```

- [ ] **Step 4.5: Build + 驗證 bundle 內容**

Run（建議 `run_in_background`）:

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Expected: `** BUILD SUCCEEDED **`。

然後驗證資源真的進了 bundle、Info.plist key 生效：

```bash
BUILT=$(xcodebuild -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -showBuildSettings 2>/dev/null | awk -F' = ' '/ BUILT_PRODUCTS_DIR/{print $2; exit}')
ls "$BUILT/NeuLedger.app/GoogleService-Info.plist"
plutil -extract FirebaseCrashlyticsCollectionEnabled raw "$BUILT/NeuLedger.app/Info.plist"
```

Expected: 第一行印出 plist 路徑（存在）；第二行印出 `false`。

- [ ] **Step 4.6: Commit**

```bash
git add Features/Sources/Core/Adapters/CrashReporting/CrashReportingBootstrap.swift \
  Features/Sources/Features/AppView.swift \
  NeuLedger/Resources/GoogleService-Info.plist \
  NeuLedger/Info.plist
git commit -m "feat(app): bootstrap firebase crashlytics at launch [ci skip]"
```

---

### Task 5: Xcode Cloud dSYM 上傳腳本

**Files:**
- Create: `ci_scripts/ci_post_xcodebuild.sh`

- [ ] **Step 5.1: 建立腳本**

新檔 `ci_scripts/ci_post_xcodebuild.sh`，完整內容：

```sh
#!/bin/sh
# Upload dSYMs to Firebase Crashlytics after archive builds.
#
# Runs in every Xcode Cloud workflow, but only does work when an archive
# exists: PR (Build + Test) workflows have no CI_ARCHIVE_PATH and skip
# silently; TestFlight / Release workflows upload the archive's dSYMs.
set -e

if [ -n "$CI_ARCHIVE_PATH" ]; then
  UPLOAD_SYMBOLS="$CI_DERIVED_DATA_PATH/SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/upload-symbols"
  "$UPLOAD_SYMBOLS" \
    -gsp "$CI_PRIMARY_REPOSITORY_PATH/NeuLedger/Resources/GoogleService-Info.plist" \
    -p ios \
    "$CI_ARCHIVE_PATH/dSYMs"
fi
```

- [ ] **Step 5.2: 設執行權限 + 語法檢查 + 驗證 upload-symbols 路徑假設**

```bash
chmod +x ci_scripts/ci_post_xcodebuild.sh
sh -n ci_scripts/ci_post_xcodebuild.sh && echo "syntax OK"
ls "$(ls -d ~/Library/Developer/Xcode/DerivedData/NeuLedger-*/SourcePackages/checkouts/firebase-ios-sdk | head -1)/Crashlytics/upload-symbols"
```

Expected: `syntax OK`；第三行印出本機 SPM checkout 內 `upload-symbols` 的路徑（證明腳本內的相對路徑 `Crashlytics/upload-symbols` 正確）。

- [ ] **Step 5.3: Commit**

```bash
git add ci_scripts/ci_post_xcodebuild.sh
git commit -m "ci: upload crashlytics dSYMs after xcode cloud archive [ci skip]"
```

---

### Task 6: 完整 scheme 驗證

**Files:** 無（純驗證）

- [ ] **Step 6.1: 跑完整測試 scheme**

Run（長時間，建議 `run_in_background`）:

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Expected: `** TEST SUCCEEDED **`，所有既有 suite 全綠（局部測試通過不能當最終驗證——必須完整 scheme）。

- [ ] **Step 6.2: 確認工作樹乾淨**

```bash
git status --short
```

Expected: 無輸出（所有變更都已分批 commit）。

---

## 收尾（plan 之外）

- PR 走 `commit-commands:commit-push-pr`（`feature/*` push 會觸發 Xcode Cloud PR workflow——是否讓 CI 跑由使用者決定）
- 使用者後續行動（spec §8）：ASC App Privacy 申報崩潰資料；首次 TestFlight 後到 Firebase Console 確認 dSYM 與崩潰回報進得來

---

## 附錄：注入模型改版（2026-06-05，PR #16 取消後）

原 Task 4.3「plist commit 進 repo」因 repo 為 public 改為注入模型（使用者裁定）。PR #16 已關閉、遠端分支已刪、本地歷史已重寫（plist 不在任何 commit）。執行紀錄：

1. 歷史重寫：`d325cbb` → `e5669de`（移除 plist）、丟棄空 CI trigger commit、`803f899` cherry-pick 自 `d192d5e`
2. `.gitignore` 加 `NeuLedger/Resources/GoogleService-Info.plist`（commit `3439448`）
3. `ci_post_clone.sh` 加 `GOOGLE_SERVICE_INFO_PLIST_B64` secret env var 解碼寫檔（round-trip 驗證 byte-identical）
4. `CrashReportingBootstrap.start()` 加 `Bundle.main` 缺檔 guard——無 plist 環境（新 clone、未設 secret 的 CI）靜默停用 crash reporting，模擬器測試不會 crash
5. 另一個排序修正：原 Task 2/3 因 `@DependencyClient` memberwise init 必填參數無法分開編譯，合併為單一 commit `7c617df`

執行差異與 spec 對應：spec §3.2/§3.4/§5/§8 已同步更新。
