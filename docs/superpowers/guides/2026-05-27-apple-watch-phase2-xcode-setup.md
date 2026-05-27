# Phase 2 — Xcode 手動設定指南

> 這份是給 **你（人類）** 跟著做的設定步驟。完成後 commit 一份「純設定變更」，然後把控制權交回 Claude，由 subagent-driven 執行 Phase 2 plan 的程式碼部分。

**完成後的狀態：**
- `NeuLedger.xcodeproj` 多了一個 `NeuLedgerWatch` watchOS App target
- `Features/Package.swift` 多了一個 `WatchFeatures` library product
- 兩者都能 build，但都還是空殼（沒有實際功能碼）

---

## Step 1：在 Xcode 加 watchOS App target

1. 打開 `NeuLedger.xcodeproj`
2. **File → New → Target...**
3. 在頂部 tab 選 **watchOS**
4. 選 **App**，按 Next
5. 設定欄位：
   - **Product Name**: `NeuLedgerWatch`
   - **Team**: 你的開發 team（同 iOS app）
   - **Organization Identifier**: 跟現有 iOS app 一致（檢查 iOS target 的 General → Bundle Identifier，取 reverse-DNS 前綴）
   - **Bundle Identifier**: 會自動變成 `<org>.NeuLedger.watchkitapp` 或類似 — 之後可以在 General tab 改
   - **Interface**: **SwiftUI**
   - **Language**: **Swift**
   - **Include Notification Scene**: ✘ **不勾**（MVP 用不到）
   - **Include Tests**: ✓ 勾（之後 Watch 端 reducer 測試會用到）
6. 按 **Finish**
7. 如果跳出「Activate scheme?」對話框，按 **Activate**

✅ **驗收：** Xcode 左側 navigator 出現 `NeuLedgerWatch/` 資料夾與 `NeuLedgerWatchTests/` 資料夾。

---

## Step 2：設 watchOS deployment target = 26.0

1. 點專案根節點 → `NeuLedgerWatch` target → **General** tab
2. **Minimum Deployments → watchOS** 設為 **26.0**
3. 同樣對 `NeuLedgerWatchTests` target 做一次

✅ **驗收：** 兩個 watch target 的 deployment 都是 26.0。

---

## Step 3：Bundle Identifier 對齊規則

iOS Watch app 的 bundle ID 慣例是 iPhone app 的 ID 加 `.watchkitapp` 後綴。

1. iOS target `NeuLedger` 的 General → Bundle Identifier，假設是：
   ```
   com.welltend.NeuLedger
   ```
2. 設 `NeuLedgerWatch` 的 Bundle Identifier 為：
   ```
   com.welltend.NeuLedger.watchkitapp
   ```
3. 設 `NeuLedgerWatchTests` 的 Bundle Identifier 為：
   ```
   com.welltend.NeuLedger.watchkitapp.tests
   ```

如果你的 iOS bundle 前綴不是 `com.welltend.NeuLedger`，把上面的字串換掉。

✅ **驗收：** 三個 target 的 bundle ID 都對齊。

---

## Step 4：App Group capability

Watch App 跟 Watch Complication（Phase 3）會共用一個 `UserDefaults(suiteName:)` 來放 `WatchContextSnapshot`。需要 App Group。

> ⚠️ **App Group 跨裝置無效**。我們這裡開 App Group 是為了「同一台 Watch 上 App 與 Complication extension 共用 sandbox」，**不是** 為了 iPhone ↔ Watch 共用（後者走 WatchConnectivity）。

1. 點 `NeuLedgerWatch` target → **Signing & Capabilities** tab
2. 左上 **+ Capability** → 選 **App Groups**
3. App Group ID 輸入：
   ```
   group.com.welltend.NeuLedger.watch
   ```
   （前綴跟你的 bundle ID 對齊；如果 bundle 前綴不是 `com.welltend.NeuLedger` 改成對應的）
4. 按勾選讓它生效（Xcode 會建立 entitlements 檔）

iOS target 不需要這個 App Group（Watch 跨裝置不共享 sandbox，iOS App 收到 WC 後寫 SwiftData 就好，不必走 App Group）。

✅ **驗收：** `NeuLedgerWatch` target 的 **Signing & Capabilities** tab 顯示 App Group 已勾選 `group.com.welltend.NeuLedger.watch`。

---

## Step 5：把 `Features` SPM package 加進 Watch target 的 dependency

> 注意：這步只把 package 加進來，但**還不選任何 product**（products 要等 Step 6 把 `WatchFeatures` 加進 Package.swift 之後才會出現）。

1. 點專案根節點 → `NeuLedgerWatch` target → **General** tab
2. 滾到 **Frameworks, Libraries, and Embedded Content**
3. 按 **+**
4. 在跳出的對話框，左下 **Add Other... → Add Package Dependency...** 通常不需要 — 因為 `Features` 已經是 local package，應該已經在搜尋清單裡。如果沒看到，往清單最底下找 **Workspace** 或 **Features** 區。
5. 暫時 **不** 加任何 product（按 Cancel）。

讓我換個說法：**這步等 Step 6 完成後再做** — 那時 `WatchFeatures` product 才會存在。先跳到 Step 6。

---

## Step 6：加 `WatchFeatures` product 到 `Features/Package.swift`

打開 `Features/Package.swift`，目前長這樣（大致）：

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Features",
    platforms: [
        .iOS("26.0"),
        // ← 加 .watchOS("26.0") 在這
    ],
    products: [
        .library(name: "Domain", targets: ["Domain"]),
        .library(name: "Core", targets: ["Core"]),
        .library(name: "Common", targets: ["Common"]),
        .library(name: "Features", targets: ["Features"]),
        // ← 加 .library(name: "WatchFeatures", ...) 在這
    ],
    dependencies: [
        // ← 不動
    ],
    targets: [
        // 現有 target...
        // ← 加 .target(name: "WatchFeatures", ...) 在這
    ],
    swiftLanguageModes: [.v6]
)
```

**改成這樣**（保留你現有的 dependencies / targets，只加箭頭指的 3 行 + 1 個新 target）：

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Features",
    platforms: [
        .iOS("26.0"),
        .watchOS("26.0"),                                  // ← 加
    ],
    products: [
        .library(name: "Domain", targets: ["Domain"]),
        .library(name: "Core", targets: ["Core"]),
        .library(name: "Common", targets: ["Common"]),
        .library(name: "Features", targets: ["Features"]),
        .library(name: "WatchFeatures", targets: ["WatchFeatures"]),  // ← 加
    ],
    dependencies: [
        // 你現有的 dependencies — 不動
    ],
    targets: [
        // 你現有的 Domain / Core / Common / Features target 定義 — 不動

        .target(                                          // ← 加整個 block
            name: "WatchFeatures",
            dependencies: [
                "Domain",
                "Core",
                "Common",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
```

> 如果你不確定 `swift-composable-architecture` 在 dependencies 區的 product 名稱，搜尋既有的 `Features` target 定義裡怎麼引用它，照抄。

**建立 source 目錄：**

```bash
mkdir -p Features/Sources/WatchFeatures
touch Features/Sources/WatchFeatures/Placeholder.swift
```

`Placeholder.swift` 內容（占位讓 SPM 不抱怨空 target）：

```swift
import Foundation

// Placeholder so SPM does not complain about an empty target.
// Removed by the first real source file in WatchFeatures.
enum WatchFeaturesPlaceholder {}
```

---

## Step 7：把 `WatchFeatures` 加進 Watch target 的 dependency

回到 Xcode（**File → Packages → Reset Package Caches** 一次，讓 SPM 重新解析）：

1. 點專案根節點 → `NeuLedgerWatch` target → **General** tab
2. 滾到 **Frameworks, Libraries, and Embedded Content**
3. 按 **+**
4. 在清單裡找 **WatchFeatures**（在 Features package 底下）
5. 加入

✅ **驗收：** `NeuLedgerWatch` target 的 General tab 列出 `WatchFeatures` 為 dependency。

---

## Step 8：把 Watch App 的預設 ContentView 改成可編譯的空殼

Xcode 自動建立的 `NeuLedgerWatch/ContentView.swift`（檔名可能是 `NeuLedgerWatchApp.swift` 或 `ContentView.swift`，看 Xcode 26 的模板）通常會用到 sample data 或 SwiftData。把它改成最簡單的：

`NeuLedgerWatch/NeuLedgerWatchApp.swift`（main entry）— 保留 Xcode 自動產生的版本即可。

`NeuLedgerWatch/ContentView.swift` — 改成：

```swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        Text("NeuLedger Watch")
            .padding()
    }
}

#Preview {
    ContentView()
}
```

✅ **驗收：** Watch App build & run on 「Apple Watch Series 10 (46mm)」 simulator，看到 "NeuLedger Watch" 字樣。

---

## Step 9：build 驗證

terminal 跑：

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedgerWatch \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)'
```

> 如果你的 Xcode 沒有 "Apple Watch Series 10 (46mm)" simulator，跑 `xcrun simctl list devicetypes | grep Watch` 看可用名稱，挑一個 watchOS 26 的取代。

✅ **驗收：** `** BUILD SUCCEEDED **`

iOS app 也要還能 build（確認 Package.swift 改動沒打壞 iOS 端）：

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

✅ **驗收：** `** BUILD SUCCEEDED **`

---

## Step 10：commit

```bash
git add NeuLedger.xcodeproj Features/Package.swift Features/Sources/WatchFeatures \
        NeuLedgerWatch NeuLedgerWatchTests
git commit -m "$(cat <<'EOF'
chore(watch): scaffold NeuLedgerWatch target and WatchFeatures SPM library [ci skip]

Adds the watchOS 26 single-target Watch app with App Group capability,
adds the WatchFeatures SPM library product alongside Domain/Core/Common/
Features, and stubs the Watch ContentView. No real functionality yet —
subsequent commits land the Watch-side clients, gateway, and reducer.

Co-Authored-By: Drake <drakehuang@welltend.com.tw>
EOF
)"
```

(這次 commit 是你親手做的，所以 Co-Authored-By 寫你自己就好，沒有 Claude footer。)

---

## 完成後回報

跟 Claude 說「Phase 2 Xcode setup done」加上：
- watchOS App bundle ID（如果你改成不一樣的前綴）
- App Group ID（如果你改成不一樣的）
- Apple Watch simulator 你用哪個（Series 10 / Ultra 2 / 其他）

我會根據這些調 Phase 2 plan 裡的字串。
