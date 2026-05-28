# Phase 3 — Complication Xcode Setup Guide

> 跟 Phase 2 一樣，這份是給你手動做的 Xcode 設定步驟。完成 + commit 之後，我用 subagent 跑 Phase 3 plan 的程式碼部分。

**完成後的狀態：**
- 多一個 `NeuLedgerWatchComplication` Widget Extension target on watchOS
- 該 target 也加入 `group.com.drake.NeuLedger` App Group capability（與 Watch app 共用 cache）
- target 自動產生的 widget stub 可以 build SUCCESS

---

## Step 1：加 widget extension target

1. 打開 Xcode
2. **File → New → Target...**
3. 頂部 tab 選 **watchOS**
4. 選 **Widget Extension**，按 Next
5. 設定：
   - **Product Name**: `NeuLedgerWatchComplication`
   - **Team**: 同 Watch app
   - **Organization Identifier**: `com.drake`
   - **Bundle Identifier**: 預設會給 `com.drake.NeuLedgerWatchComplication`，**改成** `com.drake.NeuLedger.watchkitapp.complication`（與 Watch app bundle ID 對齊，是其子 bundle）
   - **Include Configuration App Intent**: ✘ **不勾**（MVP 不需要使用者設定）
   - **Embed in Application**: dropdown 選 **NeuLedgerWatch Watch App**
6. **Finish**
7. 若跳 Activate scheme，按 Activate

---

## Step 2：watchOS deployment target = 26.0

點 `NeuLedgerWatchComplication` target → General → Minimum Deployments → watchOS = **26.0**。

---

## Step 3：App Group capability（共用 cache）

1. 點 `NeuLedgerWatchComplication` target → **Signing & Capabilities**
2. **+ Capability** → **App Groups**
3. 勾選 **既有的** `group.com.drake.NeuLedger`（與 Watch app 共用）

> 重點：**勾既有的**那一個，不要新建一個 group。Widget extension 跟 Watch app 必須共用同一個 App Group 才能讀同一份 cache。

---

## Step 4：把 WatchFeatures 加進 Complication target dependency

跟 Phase 2 Step 7 同樣流程：

1. 點 `NeuLedgerWatchComplication` target → **General** tab
2. **Frameworks, Libraries, and Embedded Content** → **`+`**
3. 搜尋 `WatchFeatures` → Add

這是為了讓 Complication 能 import `WatchFeatures` 來用 `WatchCacheStore` 跟 `WatchContextSnapshot`。

---

## Step 5：把 Complication target 加進 NeuLedgerWatchComplicationExtension Info.plist

> 預設 Widget Extension 已經自動生 Info.plist + `NSExtension` dict，**不用手動加**。檢查一下 `NeuLedgerWatchComplication/Info.plist` 存在即可。

---

## Step 6：簡化自動生成的 widget code

Xcode 會生 `NeuLedgerWatchComplication/NeuLedgerWatchComplication.swift`（或檔名類似）內含 `TimelineProvider`、`TimelineEntry`、`Widget` struct。這些之後會被 Phase 3 plan 整個換掉，但現在先讓它 build。

不用動原檔，保留 Xcode 預設即可。

---

## Step 7：Build 驗證

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme "NeuLedgerWatchComplication" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)'
```

✅ **BUILD SUCCEEDED**

也跑一下 Watch app build 確認沒被打壞：

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme "NeuLedgerWatch Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)'
```

✅ **BUILD SUCCEEDED**

---

## Step 8：Commit

```bash
git add NeuLedger.xcodeproj NeuLedgerWatchComplication
git commit -m "$(cat <<'EOF'
chore(watch): scaffold NeuLedgerWatchComplication widget extension [ci skip]

Adds the watchOS widget extension target embedded in the Watch app.
Configured with the shared group.com.drake.NeuLedger App Group so the
TimelineProvider can read the same WatchContextSnapshot the Watch
app writes. WatchFeatures linked for entity / cache access. The
auto-generated widget stub is left in place — Phase 3 plan replaces
it with TodayExpenseComplication.
EOF
)"
```

（這是你親手 commit，Co-Authored-By 寫你自己。）

---

## 完成後

跟 Claude 說「**Phase 3 Xcode setup done**」加上：
- Complication target 是否使用 ChartKit-only 那個 template（如果你有看到選項）— 我們 MVP 用純文字 + AccessoryWidgetGroup，**不需要** Charts
- Complication 的 widget 結構 struct 名稱（檢視自動生成的檔案，找 `@main` 標的 struct，例如 `NeuLedgerWatchComplicationBundle` 或 `NeuLedgerWatchComplication`）— 之後 plan 要 reference 它

拿到這些之後我繼續 Phase 3 程式碼部分。
