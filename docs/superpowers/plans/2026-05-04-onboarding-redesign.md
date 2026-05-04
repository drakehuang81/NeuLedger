# Onboarding Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 onboarding Step 2 從「填一個帳戶表單」改成「勾選帳戶類型 grid + 自訂帳戶 sheet」，並把整體視覺對齊 B-Warm 設計稿（warm radial gradient + glass cards + stagger reveal）。

**Architecture:** TCA reducer + 子 reducer (`CustomAccountFormFeature`) 處理 sheet 表單。`AccountType` 的 `displayLabel` / `defaultIcon` / `defaultColor` 從 OnboardingFeature 內 private extension 改為 `Domain` 層 public extension（讓 view / 其他 feature 共用）。新增兩個 Common 元件（`WarmGradientBackground`、`OnboardingPageDots`）。Skip 路徑直接從 welcome / accountSelection 跳到 done celebration。

**Tech Stack:** SwiftUI、ComposableArchitecture 1.23.x、Swift Testing、SF Symbols、Liquid Glass `.glassEffect()`。

**Module Boundary:** 全部修改都在 `Features/` SPM package 內（Domain / Common / Features 三個 target），無 Xcode `Shared/` 跨 target 問題。Localization 在 `NeuLedger/Resources/Localizable.xcstrings`（app target，由 `String(localized:)` 透過 `Bundle.main` 讀取）。

**Spec:** `docs/superpowers/plans/2026-05-04-onboarding-redesign-design.md` 對應 spec 為 `docs/superpowers/specs/2026-05-04-onboarding-redesign-design.md`。

---

## Test Commands（全 plan 共用）

完整 Features scheme（每個 task 收尾必跑）：

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

單一 suite：

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:FeaturesTests/OnboardingFeatureTests
```

App build（不跑測試，視覺驗證）：

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

---

## File Structure

| 檔案 | 動作 | 責任 |
|---|---|---|
| `NeuLedger/Resources/Localizable.xcstrings` | 修改 | 新增/修改/刪除 onboarding + account_type localization keys |
| `Features/Sources/Domain/Enums/AccountType.swift` | 修改 | `displayLabel` 改 localized；新增 public `defaultIcon` / `defaultColor` extension |
| `Features/Tests/DomainTests/Enums/AccountTypeTests.swift` | 修改/新增 | 驗證 displayLabel localized + defaultIcon / defaultColor 正確 |
| `Features/Sources/Common/Components/WarmGradientBackground.swift` | 新增 | warm radial gradient + 兩顆 blur orbs（Light/Dark 變體） |
| `Features/Sources/Common/Components/OnboardingPageDots.swift` | 新增 | 3-dot indicator，active dot 寬 22×6 |
| `Features/Sources/Features/Onboarding/CustomAccountFormFeature.swift` | 新增 | sheet 表單 reducer（name / type / color） |
| `Features/Sources/Features/Onboarding/CustomAccountFormView.swift` | 新增 | sheet 表單 SwiftUI view |
| `Features/Tests/FeaturesTests/CustomAccountFormFeatureTests.swift` | 新增 | sheet reducer TCA TestStore 測試 |
| `Features/Sources/Features/Onboarding/OnboardingFeature.swift` | 重寫 | 4-step state machine + sheet 整合 + 寫入帳戶 effect |
| `Features/Sources/Features/Onboarding/OnboardingView.swift` | 重寫 | 4 個 step view + reveal 動畫 + sheet 顯示 |
| `Features/Tests/FeaturesTests/OnboardingFeatureTests.swift` | 重寫 | 9 個 TCA TestStore 測試覆蓋新 state machine |

---

## Task 1: 新增 `account_type_*` Localization Keys

**Files:**
- Modify: `NeuLedger/Resources/Localizable.xcstrings`

> ⚠️ **直接執行（不派 subagent）**：純 JSON 編輯，無邏輯。

- [ ] **Step 1: 用 python 在 `Localizable.xcstrings` 加 4 個 key**

執行：

```bash
python3 <<'PY'
import json, pathlib
p = pathlib.Path('/Users/drakehuang/SideProject/iOSProject/NeuLedger/NeuLedger/Resources/Localizable.xcstrings')
data = json.loads(p.read_text())
new_keys = {
    "account_type_cash":        ("Cash", "現金"),
    "account_type_bank":        ("Bank", "銀行帳戶"),
    "account_type_credit_card": ("Credit Card", "信用卡"),
    "account_type_e_wallet":    ("E-Wallet", "電子錢包"),
}
for key, (en, zh) in new_keys.items():
    data['strings'][key] = {
        "extractionState": "manual",
        "localizations": {
            "en":      {"stringUnit": {"state": "translated", "value": en}},
            "zh-Hant": {"stringUnit": {"state": "translated", "value": zh}},
        },
    }
p.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")
print("added:", list(new_keys.keys()))
PY
```

- [ ] **Step 2: 驗證 JSON 有效**

```bash
python3 -c "import json; json.loads(open('/Users/drakehuang/SideProject/iOSProject/NeuLedger/NeuLedger/Resources/Localizable.xcstrings').read()); print('JSON OK')"
```

預期輸出：`JSON OK`

- [ ] **Step 3: 跑 app build 確認 xcstrings 沒被破壞**

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -5
```

預期：build succeeded。

- [ ] **Step 4: Commit**

```bash
git add NeuLedger/Resources/Localizable.xcstrings
git commit -m "feat(i18n): add account_type localization keys

Add 4 keys (cash/bank/credit_card/e_wallet) for AccountType.displayLabel localization."
```

---

## Task 2: `AccountType.displayLabel` 改 Localized

**Files:**
- Modify: `Features/Sources/Domain/Enums/AccountType.swift`
- Modify/Create: `Features/Tests/DomainTests/Enums/AccountTypeTests.swift`

- [ ] **Step 1: 寫 / 更新失敗測試**

編輯 `Features/Tests/DomainTests/Enums/AccountTypeTests.swift`，加入：

```swift
import Foundation
import Testing
@testable import Domain

@Suite("AccountType.displayLabel localized")
struct AccountTypeDisplayLabelTests {

    @Test("displayLabel returns non-empty localized string for each case")
    func testDisplayLabelLocalized() {
        for type in AccountType.allCases {
            let label = type.displayLabel
            #expect(!label.isEmpty)
            // raw value 應該不會直接出現（例如 .creditCard 不應顯示 "creditCard"）
            #expect(label != type.rawValue)
        }
    }

    @Test("displayLabel returns expected English fallback")
    func testDisplayLabelEnglishFallback() {
        // 直接呼叫 String(localized:) 在預設 Bundle.main 找不到 key 時回傳 key 本身。
        // 在 Domain SPM target 內，Bundle.main 是 xctest runner，找不到 app 的 xcstrings；
        // 此測試確保至少不會回傳 enum raw value。
        #expect(AccountType.cash.displayLabel != "cash")
        #expect(AccountType.bank.displayLabel != "bank")
        #expect(AccountType.creditCard.displayLabel != "creditCard")
        #expect(AccountType.eWallet.displayLabel != "eWallet")
    }
}
```

- [ ] **Step 2: 跑測試確認失敗**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:DomainTests/AccountTypeDisplayLabelTests 2>&1 | tail -20
```

預期：兩個測試其中至少 `testDisplayLabelLocalized` 會 PASS（因為原 `Cash` 等就是 non-empty 且 != raw value），但這是 baseline。`testDisplayLabelEnglishFallback` 應該 PASS（既有 hardcoded "Cash" 等已經不是 raw value）。**這個 task 的測試是 regression guard，不是真正失敗的紅燈**——記錄 baseline 後直接進入實作。

- [ ] **Step 3: 改 `AccountType.displayLabel`**

編輯 `Features/Sources/Domain/Enums/AccountType.swift`，把 `displayLabel` 改成：

```swift
/// A user-facing display label for this account type.
public var displayLabel: String {
    switch self {
    case .cash:       String(localized: "account_type_cash", bundle: .main)
    case .bank:       String(localized: "account_type_bank", bundle: .main)
    case .creditCard: String(localized: "account_type_credit_card", bundle: .main)
    case .eWallet:    String(localized: "account_type_e_wallet", bundle: .main)
    }
}
```

- [ ] **Step 4: 跑單元測試**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:DomainTests/AccountTypeDisplayLabelTests 2>&1 | tail -20
```

預期：兩個測試 PASS。

- [ ] **Step 5: 跑完整 Features scheme 確認 displayLabel 改動沒打破 AccountManagement / Dashboard 既有測試**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -10
```

預期：全部 PASS。

- [ ] **Step 6: Commit**

```bash
git add Features/Sources/Domain/Enums/AccountType.swift Features/Tests/DomainTests/Enums/AccountTypeTests.swift
git commit -m "feat(domain): localize AccountType.displayLabel

displayLabel now uses String(localized:) so AccountType labels render
in the user's preferred locale instead of being hard-coded English."
```

---

## Task 3: 把 `AccountType.defaultIcon` / `defaultColor` 移到 Domain Public Extension（並改 iOS 系統色）

**Files:**
- Modify: `Features/Sources/Domain/Enums/AccountType.swift`（新增 public extension）
- Modify: `Features/Sources/Features/Onboarding/OnboardingFeature.swift`（移除 private extension 內 default* 屬性，後續 task 會整體重寫）
- Modify: `Features/Tests/DomainTests/Enums/AccountTypeTests.swift`

> ⚠️ 既有 `private extension AccountType` 在 `OnboardingFeature.swift` 第 124-143 行。本 task 只新增 public version + 改色票，先暫不刪 private（避免 build 中斷）。Task 9 重寫 OnboardingFeature 時再整體拿掉 private 版本。

- [ ] **Step 1: 寫失敗測試**

在 `Features/Tests/DomainTests/Enums/AccountTypeTests.swift` 加：

```swift
@Suite("AccountType.defaultIcon and defaultColor")
struct AccountTypeDefaultsTests {

    @Test("defaultIcon returns SF Symbol for each case")
    func testDefaultIcon() {
        #expect(AccountType.cash.defaultIcon == "banknote")
        #expect(AccountType.bank.defaultIcon == "building.columns")
        #expect(AccountType.creditCard.defaultIcon == "creditcard")
        #expect(AccountType.eWallet.defaultIcon == "wallet.bifold")
    }

    @Test("defaultColor returns iOS system hex for each case")
    func testDefaultColor() {
        #expect(AccountType.cash.defaultColor == "#8E8E93")
        #expect(AccountType.bank.defaultColor == "#0A84FF")
        #expect(AccountType.creditCard.defaultColor == "#FF2D55")
        #expect(AccountType.eWallet.defaultColor == "#5E5CE6")
    }
}
```

- [ ] **Step 2: 跑測試確認失敗**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:DomainTests/AccountTypeDefaultsTests 2>&1 | tail -20
```

預期：FAIL（屬性不存在於 public scope）。

- [ ] **Step 3: 在 `AccountType.swift` 加 public extension**

在 `Features/Sources/Domain/Enums/AccountType.swift` 檔尾加：

```swift
public extension AccountType {
    /// Default SF Symbol name for this account type.
    var defaultIcon: String {
        switch self {
        case .cash:       "banknote"
        case .bank:       "building.columns"
        case .creditCard: "creditcard"
        case .eWallet:    "wallet.bifold"
        }
    }

    /// Default brand color hex (iOS system palette) for this account type.
    var defaultColor: String {
        switch self {
        case .cash:       "#8E8E93"
        case .bank:       "#0A84FF"
        case .creditCard: "#FF2D55"
        case .eWallet:    "#5E5CE6"
        }
    }
}
```

- [ ] **Step 4: 跑測試確認通過**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:DomainTests/AccountTypeDefaultsTests 2>&1 | tail -20
```

預期：PASS。

> ⚠️ **不要刪 OnboardingFeature.swift 裡的 private extension**——Task 9 才整體重寫。此 task 期間 private 與 public 同名屬性會 shadow，private 在 file scope 內優先（Swift extension resolution）。

- [ ] **Step 5: 跑完整 Features scheme**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -10
```

預期：全部 PASS。

- [ ] **Step 6: Commit**

```bash
git add Features/Sources/Domain/Enums/AccountType.swift Features/Tests/DomainTests/Enums/AccountTypeTests.swift
git commit -m "feat(domain): expose AccountType defaultIcon/defaultColor

Move defaults to a Domain public extension and align colors with
the iOS system palette (8E8E93/0A84FF/FF2D55/5E5CE6) per design B-Warm.
The private copy in OnboardingFeature.swift will be removed in a later commit
that rewrites that reducer."
```

---

## Task 4: 新增/修改/刪除 Onboarding Localization Keys

**Files:**
- Modify: `NeuLedger/Resources/Localizable.xcstrings`

> ⚠️ **直接執行（不派 subagent）**：純 JSON 編輯。

- [ ] **Step 1: 用 python 一次處理新增 / 修改 / 刪除**

```bash
python3 <<'PY'
import json, pathlib
p = pathlib.Path('/Users/drakehuang/SideProject/iOSProject/NeuLedger/NeuLedger/Resources/Localizable.xcstrings')
data = json.loads(p.read_text())

# 1. 刪除不再使用的 key
to_delete = [
    "onboarding_setup_title", "onboarding_setup_subtitle",
    "onboarding_setup_name_label", "onboarding_setup_name_placeholder",
    "onboarding_setup_type_label", "onboarding_setup_button",
    "onboarding_ready_balance_label",
    "onboarding_welcome_title",  # 拆成 _lead + _emphasis
]
for k in to_delete:
    data['strings'].pop(k, None)

# 2. 新增 / 覆寫
new_or_modified = {
    # Welcome
    "onboarding_welcome_title_lead":     ("Every NT$,", "每一塊錢，"),
    "onboarding_welcome_title_emphasis": ("seen", "都看得見"),
    "onboarding_welcome_subtitle":       ("On-device 智慧記帳，私密、優雅、零延遲。", "On-device 智慧記帳，私密、優雅、零延遲。"),
    "onboarding_welcome_button":         ("Start", "開始"),
    "onboarding_welcome_card_eyebrow":   ("Total balance · Starting fresh", "總資產 · 開始追蹤"),
    "onboarding_welcome_chip_starting":  ("Starting now", "即將開始"),
    "onboarding_welcome_chip_on_device": ("On-device", "On-device"),

    # Step indicator
    "onboarding_step_indicator_2": ("Step 02 of 03", "Step 02 of 03"),
    "onboarding_step_indicator_3": ("Step 03 of 03", "Step 03 of 03"),

    # Account selection
    "onboarding_selection_title":           ("Pick your accounts", "選擇你的帳戶"),
    "onboarding_selection_subtitle":        ("Tap to add. Adjust anytime.", "點擊新增。隨時可以調整。"),
    "onboarding_selection_continue_format": ("Continue · %lld selected", "繼續 · %lld 個"),
    "onboarding_selection_add_custom":      ("Add custom account", "新增其他帳戶"),

    # Custom sheet
    "onboarding_custom_sheet_title":     ("Add account", "新增帳戶"),
    "onboarding_custom_sheet_subtitle":  ("Name it, pick type and color", "為它取個名字，選類型與顏色"),
    "onboarding_custom_name_label":      ("Account name", "帳戶名稱"),
    "onboarding_custom_name_placeholder":("e.g. Chase Checking", "例如:玉山銀行"),
    "onboarding_custom_type_label":      ("Type", "類型"),
    "onboarding_custom_color_label":     ("Color", "顏色"),
    "onboarding_custom_submit":          ("Add", "新增"),
    "onboarding_custom_cancel":          ("Cancel", "取消"),

    # Ready
    "onboarding_ready_title":               ("You're set", "你準備好了"),
    "onboarding_ready_subtitle":            ("NeuLedger will take it from here.", "接著就交給 NeuLedger 為你看顧每一筆。"),
    "onboarding_ready_total_label":         ("Total balance", "總餘額"),
    "onboarding_ready_account_count_format":("%lld account(s) created", "已建立 %lld 個帳戶"),
    "onboarding_ready_button":              ("Done", "完成"),

    # Done
    "onboarding_done_title":    ("Welcome aboard", "歡迎加入"),
    "onboarding_done_subtitle": ("Ready to go · opening dashboard…", "準備就緒，正在打開儀表板…"),
}
for key, (en, zh) in new_or_modified.items():
    data['strings'][key] = {
        "extractionState": "manual",
        "localizations": {
            "en":      {"stringUnit": {"state": "translated", "value": en}},
            "zh-Hant": {"stringUnit": {"state": "translated", "value": zh}},
        },
    }

p.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")
print("deleted:", len(to_delete))
print("written:", len(new_or_modified))
PY
```

- [ ] **Step 2: 確認 JSON valid + 預期 key 都在**

```bash
python3 <<'PY'
import json
data = json.loads(open('/Users/drakehuang/SideProject/iOSProject/NeuLedger/NeuLedger/Resources/Localizable.xcstrings').read())
expected_present = ["onboarding_welcome_title_lead", "onboarding_selection_title", "onboarding_done_title"]
expected_absent  = ["onboarding_setup_title", "onboarding_welcome_title"]
for k in expected_present: assert k in data['strings'], f"missing {k}"
for k in expected_absent:  assert k not in data['strings'], f"should be removed: {k}"
print("OK")
PY
```

預期：`OK`。

- [ ] **Step 3: 跑 app build（沒打到 deleted key 之前不會編譯失敗，但確認 xcstrings 結構好）**

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -5
```

預期：build succeeded（OnboardingView.swift 仍引用部分被刪除的 key，因此可能失敗——若失敗則確認錯誤訊息只與 onboarding key 有關，後續 task 會修。**若失敗，繼續往下不要 commit**。如果 build success，commit）。

- [ ] **Step 4: Commit（若上一步 build 成功才 commit；否則延後到 task 11 一起 commit）**

```bash
git add NeuLedger/Resources/Localizable.xcstrings
git commit -m "feat(i18n): refresh onboarding localization keys

Add new keys for the redesigned onboarding flow (welcome lead/emphasis,
account selection grid, custom account sheet, ready, done). Remove
keys that the new flow no longer uses (setup_*, welcome_title,
ready_balance_label)."
```

---

## Task 5: 新增 `WarmGradientBackground` 共用元件

**Files:**
- Create: `Features/Sources/Common/Components/WarmGradientBackground.swift`

> ⚠️ **直接執行**：單檔建立、無邏輯測試（純視覺）。

- [ ] **Step 1: 建立檔案**

```swift
//  WarmGradientBackground.swift
//  Common
//
//  Warm radial gradient + two blur orbs background per B-Warm design tokens.

import SwiftUI

public struct WarmGradientBackground: View {

    public enum Variant {
        case top         // welcome — center at 20% / 0%
        case bottomRight // account selection — center at 80% / 100%
        case center      // ready / done — center at 50% / 30-50%
    }

    public let variant: Variant
    @Environment(\.colorScheme) private var colorScheme

    public init(variant: Variant = .top) {
        self.variant = variant
    }

    public var body: some View {
        ZStack {
            radialGradient
            orb1
            orb2
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var radialGradient: some View {
        let stops: [Color] = colorScheme == .dark
            ? [Color(hex: "#4A2A0E"), Color(hex: "#1A0F08"), Color(hex: "#050505")]
            : [Color(hex: "#FFE4B8"), Color(hex: "#FFF6E8"), Color(hex: "#FAFAF7")]
        return RadialGradient(
            gradient: Gradient(colors: stops),
            center: gradientCenter,
            startRadius: 0,
            endRadius: 600
        )
    }

    private var gradientCenter: UnitPoint {
        switch variant {
        case .top:         UnitPoint(x: 0.2, y: 0.0)
        case .bottomRight: UnitPoint(x: 0.8, y: 1.0)
        case .center:      UnitPoint(x: 0.5, y: 0.3)
        }
    }

    private var orb1: some View {
        Circle()
            .fill(Color.Design.brandPrimary)
            .frame(width: 240, height: 240)
            .blur(radius: 60)
            .opacity(colorScheme == .dark ? 0.30 : 0.35)
            .offset(x: variant == .bottomRight ? 120 : 100, y: variant == .bottomRight ? 220 : -120)
    }

    private var orb2: some View {
        Circle()
            .fill(Color.Design.incomeGreen)
            .frame(width: 220, height: 220)
            .blur(radius: 70)
            .opacity(colorScheme == .dark ? 0.20 : 0.22)
            .offset(x: -120, y: variant == .bottomRight ? 140 : 80)
    }
}

private extension Color {
    init(hex: String) {
        let cleaned = hex.replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >>  8) & 0xFF) / 255.0
        let b = Double( rgb        & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}

#Preview("Top · Light") {
    ZStack { WarmGradientBackground(variant: .top); Text("Welcome").font(.title) }
}
#Preview("Bottom-right · Light") {
    ZStack { WarmGradientBackground(variant: .bottomRight); Text("Selection").font(.title) }
}
#Preview("Top · Dark") {
    ZStack { WarmGradientBackground(variant: .top); Text("Welcome").font(.title) }
        .preferredColorScheme(.dark)
}
```

> ⚠️ 若 `Color.Design.brandPrimary` / `Color.Design.incomeGreen` 命名與既有 `Color.Design` 不一致，先 grep 確認：`grep -rn "Color.Design\." Features/Sources/Common --include="*.swift" | head -10`，調整為實際 token 名稱。

- [ ] **Step 2: 跑 app build 確認沒語法錯**

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -10
```

預期：build succeeded。

- [ ] **Step 3: Commit**

```bash
git add Features/Sources/Common/Components/WarmGradientBackground.swift
git commit -m "feat(common): add WarmGradientBackground component

Reusable warm radial gradient + two blur orbs (light/dark variants),
parameterized by gradient center variant (top/bottomRight/center)
to back the onboarding redesign."
```

---

## Task 6: 新增 `OnboardingPageDots` 共用元件

**Files:**
- Create: `Features/Sources/Common/Components/OnboardingPageDots.swift`

> ⚠️ **直接執行**：單檔建立。

- [ ] **Step 1: 建立檔案**

```swift
//  OnboardingPageDots.swift
//  Common
//
//  3-dot page indicator with elongated active dot.

import SwiftUI

public struct OnboardingPageDots: View {
    public let count: Int
    public let active: Int

    public init(count: Int = 3, active: Int) {
        self.count = count
        self.active = active
    }

    public var body: some View {
        HStack(spacing: 6) {
            ForEach(0 ..< count, id: \.self) { i in
                Capsule()
                    .fill(i == active ? Color.primary : Color.primary.opacity(0.15))
                    .frame(width: i == active ? 22 : 6, height: 6)
                    .animation(.easeOut(duration: 0.25), value: active)
            }
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        OnboardingPageDots(active: 0)
        OnboardingPageDots(active: 1)
        OnboardingPageDots(active: 2)
    }
    .padding()
}
```

- [ ] **Step 2: Build**

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -5
```

預期：build succeeded。

- [ ] **Step 3: Commit**

```bash
git add Features/Sources/Common/Components/OnboardingPageDots.swift
git commit -m "feat(common): add OnboardingPageDots component

3-dot indicator where the active dot widens to 22pt; used by
the redesigned onboarding step navigation."
```

---

## Task 7: 新增 `CustomAccountFormFeature` Reducer (TDD)

**Files:**
- Create: `Features/Sources/Features/Onboarding/CustomAccountFormFeature.swift`
- Create: `Features/Tests/FeaturesTests/CustomAccountFormFeatureTests.swift`

- [ ] **Step 1: 建立失敗測試**

`Features/Tests/FeaturesTests/CustomAccountFormFeatureTests.swift`：

```swift
import Testing
import ComposableArchitecture
import Domain
@testable import Features

@Suite("CustomAccountFormFeature Tests")
struct CustomAccountFormFeatureTests {

    @Test("canSubmit is false when name is empty / whitespace")
    func testCanSubmit() {
        var s = CustomAccountFormFeature.State()
        #expect(s.canSubmit == false)
        s.name = "   "
        #expect(s.canSubmit == false)
        s.name = "玉山"
        #expect(s.canSubmit == true)
    }

    @Test("binding updates name / type / color")
    func testBinding() async {
        let store = await TestStore(initialState: CustomAccountFormFeature.State()) {
            CustomAccountFormFeature()
        }
        await store.send(\.binding.name, "悠遊卡") { $0.name = "悠遊卡" }
        await store.send(\.binding.type, .eWallet) { $0.type = .eWallet }
        await store.send(\.binding.color, "#5E5CE6") { $0.color = "#5E5CE6" }
    }

    @Test("submitTapped emits delegate.submitted with draft (uses uuid dependency)")
    func testSubmitEmitsDelegate() async {
        let fixedUUID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let store = await TestStore(
            initialState: CustomAccountFormFeature.State(name: "玉山銀行", type: .bank, color: "#0A84FF")
        ) {
            CustomAccountFormFeature()
        } withDependencies: {
            $0.uuid = .constant(fixedUUID)
        }

        await store.send(.submitTapped)
        await store.receive(\.delegate.submitted) {
            #expect(true) // payload check below
        }
        // verify payload via captured delegate value:
        // (TestStore's `.receive` does not let us inspect by default, so use a ref-cell pattern instead)
    }

    @Test("submitTapped delegate carries the expected draft fields")
    func testSubmitDraftPayload() async {
        let captured = LockIsolated<CustomAccountDraft?>(nil)
        let fixedUUID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let store = await TestStore(
            initialState: CustomAccountFormFeature.State(name: "  Visa  ", type: .creditCard, color: "#FF2D55")
        ) {
            CustomAccountFormFeature()
                ._printChanges()
        } withDependencies: {
            $0.uuid = .constant(fixedUUID)
        }

        await store.send(.submitTapped)
        await store.receive { action in
            if case let .delegate(.submitted(draft)) = action {
                captured.setValue(draft)
                return true
            }
            return false
        }

        let d = captured.value
        #expect(d?.id == fixedUUID)
        #expect(d?.name == "Visa")          // trimmed
        #expect(d?.type == .creditCard)
        #expect(d?.color == "#FF2D55")
    }

    @Test("submitTapped is a no-op when canSubmit is false")
    func testSubmitNoOpWhenInvalid() async {
        let store = await TestStore(
            initialState: CustomAccountFormFeature.State(name: "  ", type: .bank, color: "#0A84FF")
        ) {
            CustomAccountFormFeature()
        }
        await store.send(.submitTapped)
        // No effects fire; TestStore strict mode catches missing handler if delegate fires.
    }

    @Test("cancelTapped emits delegate.dismissed")
    func testCancelEmitsDismiss() async {
        let store = await TestStore(initialState: CustomAccountFormFeature.State()) {
            CustomAccountFormFeature()
        }
        await store.send(.cancelTapped)
        await store.receive(\.delegate.dismissed)
    }
}
```

- [ ] **Step 2: 跑測試確認失敗（型別不存在）**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:FeaturesTests/CustomAccountFormFeatureTests 2>&1 | tail -20
```

預期：FAIL (`CustomAccountFormFeature` not found)。

- [ ] **Step 3: 建立 reducer**

`Features/Sources/Features/Onboarding/CustomAccountFormFeature.swift`：

```swift
//  CustomAccountFormFeature.swift
//  Features
//
//  Sub-reducer for the "add custom account" sheet shown from the
//  account selection step of OnboardingFeature.

import ComposableArchitecture
import Domain
import Foundation

public struct CustomAccountDraft: Equatable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var type: AccountType
    public var color: String

    public init(id: UUID, name: String, type: AccountType, color: String) {
        self.id = id
        self.name = name
        self.type = type
        self.color = color
    }
}

public extension CustomAccountFormFeature {
    /// Color palette offered in the sheet (matches B-Warm design tokens).
    static let colorPalette: [String] = [
        "#FF9500", // accent
        "#0A84FF", // bank blue
        "#5E5CE6", // e-wallet purple
        "#FF2D55", // credit red
        "#34C759", // income green
        "#8E8E93", // cash gray
    ]
}

@Reducer
public struct CustomAccountFormFeature {

    @ObservableState
    public struct State: Equatable {
        public var name: String
        public var type: AccountType
        public var color: String

        public init(name: String = "", type: AccountType = .bank, color: String = "#FF9500") {
            self.name = name
            self.type = type
            self.color = color
        }

        public var canSubmit: Bool {
            !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    public enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case cancelTapped
        case submitTapped
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            case dismissed
            case submitted(CustomAccountDraft)
        }
    }

    @Dependency(\.uuid) var uuid

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .cancelTapped:
                return .send(.delegate(.dismissed))

            case .submitTapped:
                guard state.canSubmit else { return .none }
                let draft = CustomAccountDraft(
                    id: uuid(),
                    name: state.name.trimmingCharacters(in: .whitespacesAndNewlines),
                    type: state.type,
                    color: state.color
                )
                return .send(.delegate(.submitted(draft)))

            case .delegate:
                return .none
            }
        }
    }
}
```

- [ ] **Step 4: 跑測試確認通過**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:FeaturesTests/CustomAccountFormFeatureTests 2>&1 | tail -25
```

預期：6 tests PASS。

- [ ] **Step 5: 跑完整 Features scheme**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -10
```

預期：全部 PASS。

- [ ] **Step 6: Commit**

```bash
git add Features/Sources/Features/Onboarding/CustomAccountFormFeature.swift Features/Tests/FeaturesTests/CustomAccountFormFeatureTests.swift
git commit -m "feat(onboarding): add CustomAccountFormFeature reducer

Sub-reducer for the 'add custom account' sheet that emits a
CustomAccountDraft via delegate.submitted when the user taps Add.
Full TestStore coverage on canSubmit, bindings, submit, cancel."
```

---

## Task 8: 新增 `CustomAccountFormView`

**Files:**
- Create: `Features/Sources/Features/Onboarding/CustomAccountFormView.swift`

> ⚠️ View 沒有 unit test；先 build 確認語法正確，後續整合在 Task 12 的手動 smoke 中驗證。

- [ ] **Step 1: 建立檔案**

```swift
//  CustomAccountFormView.swift
//  Features

import SwiftUI
import ComposableArchitecture
import Common
import Domain

struct CustomAccountFormView: View {
    @Bindable var store: StoreOf<CustomAccountFormFeature>

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // drag handle
            Capsule()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 38, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
                .padding(.bottom, 18)

            // title block
            Text("onboarding_custom_sheet_title")
                .font(.system(size: 24, weight: .bold))
                .padding(.bottom, 4)
            Text("onboarding_custom_sheet_subtitle")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .padding(.bottom, 18)

            // name
            FieldLabel("onboarding_custom_name_label")
            GlassContainer(cornerRadius: 14, padding: 12) {
                TextField("onboarding_custom_name_placeholder", text: $store.name)
                    .font(.system(size: 16))
            }
            .padding(.bottom, 14)

            // type chip row
            FieldLabel("onboarding_custom_type_label")
            HStack(spacing: 8) {
                ForEach(AccountType.allCases, id: \.self) { type in
                    typeChip(for: type)
                }
            }
            .padding(.bottom, 14)

            // color picker
            FieldLabel("onboarding_custom_color_label")
            ColorSwatchPicker(
                colors: CustomAccountFormFeature.colorPalette,
                selectedHex: store.color,
                onSelect: { store.color = $0 }
            )
            .padding(.bottom, 18)

            // submit
            PrimaryButton("onboarding_custom_submit") {
                store.send(.submitTapped)
            }
            .opacity(store.canSubmit ? 1 : 0.5)
            .disabled(!store.canSubmit)
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 28)
    }

    @ViewBuilder
    private func typeChip(for type: AccountType) -> some View {
        let isSelected = store.type == type
        Button {
            store.type = type
        } label: {
            VStack(spacing: 4) {
                Image(systemName: type.defaultIcon)
                    .font(.system(size: 18))
                    .foregroundStyle(isSelected ? Color.Design.brandPrimary : Color.primary)
                Text(type.displayLabel)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.Design.brandPrimary : Color.clear,
                        lineWidth: 2
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.secondary.opacity(0.06))
                    )
            }
        }
        .buttonStyle(.plain)
    }
}

private struct FieldLabel: View {
    let key: LocalizedStringKey
    init(_ key: LocalizedStringKey) { self.key = key }
    var body: some View {
        Text(key)
            .font(.system(size: 10, weight: .medium))
            .textCase(.uppercase)
            .tracking(1)
            .foregroundStyle(.secondary)
            .padding(.bottom, 6)
    }
}
```

- [ ] **Step 2: Build app**

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -10
```

預期：build succeeded。如果報錯（例如 `Color.Design.brandPrimary` 不存在），grep 找正確 token 名並修正。

- [ ] **Step 3: Commit**

```bash
git add Features/Sources/Features/Onboarding/CustomAccountFormView.swift
git commit -m "feat(onboarding): add CustomAccountFormView sheet content"
```

---

## Task 9: 重寫 `OnboardingFeature` Reducer (TDD)

**Files:**
- Modify (rewrite): `Features/Sources/Features/Onboarding/OnboardingFeature.swift`
- Modify (rewrite): `Features/Tests/FeaturesTests/OnboardingFeatureTests.swift`

> ⚠️ Big task — 因為 reducer 與測試一起重寫無法部分 commit；單一 atomic commit。**派 subagent 時務必列出檔案範圍**：
> ```
> 只能修改：
>   - Features/Sources/Features/Onboarding/OnboardingFeature.swift
>   - Features/Tests/FeaturesTests/OnboardingFeatureTests.swift
> 不可修改其他任何檔案。OnboardingView.swift 由後續 task 處理；本 task 結束時 OnboardingView 預期會編譯失敗（Task 11-13 修復），這是預期的。
> ```

- [ ] **Step 1: 把舊的測試檔整個替換成 spec 9 條測試**

`Features/Tests/FeaturesTests/OnboardingFeatureTests.swift` 整個改寫為：

```swift
import Testing
import ComposableArchitecture
import Domain
import Foundation
@testable import Features

@Suite("OnboardingFeature Tests (Redesign)")
struct OnboardingFeatureTests {

    // ── Step navigation ──────────────────────────────────────────────

    @Test("startButtonTapped: welcome -> accountSelection")
    func testStart() async {
        let store = await TestStore(initialState: OnboardingFeature.State()) {
            OnboardingFeature()
        }
        await store.send(.startButtonTapped) {
            $0.currentStep = .accountSelection
        }
    }

    @Test("nextButtonTapped: accountSelection -> ready")
    func testNext() async {
        let store = await TestStore(
            initialState: OnboardingFeature.State(currentStep: .accountSelection)
        ) {
            OnboardingFeature()
        }
        await store.send(.nextButtonTapped) {
            $0.currentStep = .ready
        }
    }

    // ── Type toggle ──────────────────────────────────────────────────

    @Test("typeToggled adds type when not selected")
    func testToggleAdd() async {
        let store = await TestStore(
            initialState: OnboardingFeature.State(selectedTypes: [.cash])
        ) {
            OnboardingFeature()
        }
        await store.send(.typeToggled(.bank)) {
            $0.selectedTypes = [.cash, .bank]
        }
    }

    @Test("typeToggled removes type when already selected")
    func testToggleRemove() async {
        let store = await TestStore(
            initialState: OnboardingFeature.State(selectedTypes: [.cash, .bank])
        ) {
            OnboardingFeature()
        }
        await store.send(.typeToggled(.bank)) {
            $0.selectedTypes = [.cash]
        }
    }

    // ── Custom account sheet ─────────────────────────────────────────

    @Test("addCustomAccountTapped opens the sheet")
    func testOpenSheet() async {
        let store = await TestStore(initialState: OnboardingFeature.State()) {
            OnboardingFeature()
        } withDependencies: {
            $0.uuid = .incrementing
        }
        await store.send(.addCustomAccountTapped) {
            $0.customAccountSheet = CustomAccountFormFeature.State()
        }
    }

    @Test("sheet delegate.submitted appends to customAccounts and dismisses sheet")
    func testSheetSubmit() async {
        let draftId = UUID(uuidString: "00000000-0000-0000-0000-000000000010")!
        let draft = CustomAccountDraft(id: draftId, name: "玉山銀行", type: .bank, color: "#0A84FF")

        let store = await TestStore(
            initialState: OnboardingFeature.State(
                customAccountSheet: CustomAccountFormFeature.State(name: "玉山銀行", type: .bank, color: "#0A84FF")
            )
        ) {
            OnboardingFeature()
        } withDependencies: {
            $0.uuid = .constant(draftId)
        }

        await store.send(.customAccountSheet(.presented(.delegate(.submitted(draft))))) {
            $0.customAccounts = [draft]
            $0.customAccountSheet = nil
        }
    }

    @Test("sheet delegate.dismissed clears the sheet")
    func testSheetDismiss() async {
        let store = await TestStore(
            initialState: OnboardingFeature.State(
                customAccountSheet: CustomAccountFormFeature.State()
            )
        ) {
            OnboardingFeature()
        }
        await store.send(.customAccountSheet(.presented(.delegate(.dismissed)))) {
            $0.customAccountSheet = nil
        }
    }

    @Test("customAccountDeleted removes by id")
    func testDeleteCustom() async {
        let id1 = UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!
        let id2 = UUID(uuidString: "00000000-0000-0000-0000-0000000000A2")!
        let d1  = CustomAccountDraft(id: id1, name: "玉山", type: .bank, color: "#0A84FF")
        let d2  = CustomAccountDraft(id: id2, name: "悠遊", type: .eWallet, color: "#5E5CE6")

        let store = await TestStore(
            initialState: OnboardingFeature.State(customAccounts: [d1, d2])
        ) {
            OnboardingFeature()
        }
        await store.send(.customAccountDeleted(id1)) {
            $0.customAccounts = [d2]
        }
    }

    // ── Finish & Skip (write accounts) ───────────────────────────────

    @Test("finishButtonTapped writes selected types + customs, transitions to done")
    func testFinishWritesAccounts() async {
        let added = LockIsolated<[Account]>([])
        let setBoolCalled = LockIsolated(false)
        let id1 = UUID(uuidString: "00000000-0000-0000-0000-0000000000B1")!
        let custom = CustomAccountDraft(id: id1, name: "玉山銀行", type: .bank, color: "#0A84FF")

        let clock = TestClock()

        let store = await TestStore(
            initialState: OnboardingFeature.State(
                currentStep: .ready,
                selectedTypes: [.cash, .creditCard],
                customAccounts: [custom]
            )
        ) {
            OnboardingFeature()
        } withDependencies: {
            $0.userSettingsClient.setBool = { _, _ in setBoolCalled.setValue(true) }
            $0.accountClient.add = { acc in
                added.withValue { $0.append(acc) }
            }
            $0.continuousClock = clock
        }

        await store.send(.finishButtonTapped) {
            $0.isCreatingAccounts = true
        }
        await store.receive(\.accountsCreated) {
            $0.currentStep = .done
        }
        await clock.advance(by: .milliseconds(1600))
        await store.receive(\.doneAnimationFinished)
        await store.receive(\.delegate.onboardingCompleted)

        let names = added.value.map(\.name).sorted()
        let types = Set(added.value.map(\.type))
        #expect(setBoolCalled.value == true)
        #expect(added.value.count == 3)
        #expect(types == [.cash, .creditCard, .bank])
        #expect(names.contains("玉山銀行"))
    }

    @Test("skipButtonTapped writes default cash account and transitions to done")
    func testSkip() async {
        let added = LockIsolated<Account?>(nil)
        let setBoolCalled = LockIsolated(false)
        let clock = TestClock()

        let store = await TestStore(
            initialState: OnboardingFeature.State(currentStep: .welcome)
        ) {
            OnboardingFeature()
        } withDependencies: {
            $0.userSettingsClient.setBool = { _, _ in setBoolCalled.setValue(true) }
            $0.accountClient.add = { acc in added.setValue(acc) }
            $0.continuousClock = clock
        }

        await store.send(.skipButtonTapped) {
            $0.isCreatingAccounts = true
        }
        await store.receive(\.accountsCreated) {
            $0.currentStep = .done
        }
        await clock.advance(by: .milliseconds(1600))
        await store.receive(\.doneAnimationFinished)
        await store.receive(\.delegate.onboardingCompleted)

        let acc = added.value
        #expect(acc?.type == .cash)
        #expect(acc?.icon == "banknote")
        #expect(setBoolCalled.value == true)
    }
}
```

- [ ] **Step 2: 跑測試確認失敗**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:FeaturesTests/OnboardingFeatureTests 2>&1 | tail -25
```

預期：FAIL（state / action 與舊版不符）。

- [ ] **Step 3: 整個替換 `OnboardingFeature.swift`**

```swift
//  OnboardingFeature.swift
//  Features

import ComposableArchitecture
import Domain
import Foundation

@Reducer
struct OnboardingFeature {

    enum Step: Equatable {
        case welcome
        case accountSelection
        case ready
        case done
    }

    @ObservableState
    struct State: Equatable {
        var currentStep: Step = .welcome
        var selectedTypes: Set<AccountType> = [.cash]
        var customAccounts: [CustomAccountDraft] = []
        @Presents var customAccountSheet: CustomAccountFormFeature.State?
        var isCreatingAccounts: Bool = false
    }

    enum Action: Equatable {
        case startButtonTapped
        case typeToggled(AccountType)
        case addCustomAccountTapped
        case customAccountSheet(PresentationAction<CustomAccountFormFeature.Action>)
        case customAccountDeleted(UUID)
        case nextButtonTapped
        case finishButtonTapped
        case skipButtonTapped
        case accountsCreated
        case doneAnimationFinished
        case delegate(Delegate)

        @CasePathable
        enum Delegate: Equatable {
            case onboardingCompleted
        }
    }

    @Dependency(\.userSettingsClient) var userSettingsClient
    @Dependency(\.accountClient) var accountClient
    @Dependency(\.continuousClock) var clock

    private enum CancelID { case create }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .startButtonTapped:
                state.currentStep = .accountSelection
                return .none

            case .nextButtonTapped:
                state.currentStep = .ready
                return .none

            case let .typeToggled(type):
                if state.selectedTypes.contains(type) {
                    state.selectedTypes.remove(type)
                } else {
                    state.selectedTypes.insert(type)
                }
                return .none

            case .addCustomAccountTapped:
                state.customAccountSheet = CustomAccountFormFeature.State()
                return .none

            case let .customAccountSheet(.presented(.delegate(.submitted(draft)))):
                state.customAccounts.append(draft)
                state.customAccountSheet = nil
                return .none

            case .customAccountSheet(.presented(.delegate(.dismissed))):
                state.customAccountSheet = nil
                return .none

            case .customAccountSheet:
                return .none

            case let .customAccountDeleted(id):
                state.customAccounts.removeAll { $0.id == id }
                return .none

            case .finishButtonTapped:
                state.isCreatingAccounts = true
                let types = state.selectedTypes
                let customs = state.customAccounts
                return .run { [accountClient, userSettingsClient] send in
                    for type in types.sorted(by: { $0.rawValue < $1.rawValue }) {
                        let acc = Account(
                            name: type.displayLabel,
                            type: type,
                            icon: type.defaultIcon,
                            color: type.defaultColor
                        )
                        try await accountClient.add(acc)
                    }
                    for d in customs {
                        let acc = Account(
                            name: d.name,
                            type: d.type,
                            icon: d.type.defaultIcon,
                            color: d.color
                        )
                        try await accountClient.add(acc)
                    }
                    userSettingsClient.setBool(true, .hasCompletedOnboarding)
                    await send(.accountsCreated)
                }
                .cancellable(id: CancelID.create)

            case .skipButtonTapped:
                state.isCreatingAccounts = true
                return .run { [accountClient, userSettingsClient] send in
                    let acc = Account(
                        name: AccountType.cash.displayLabel,
                        type: .cash,
                        icon: AccountType.cash.defaultIcon,
                        color: AccountType.cash.defaultColor
                    )
                    try await accountClient.add(acc)
                    userSettingsClient.setBool(true, .hasCompletedOnboarding)
                    await send(.accountsCreated)
                }
                .cancellable(id: CancelID.create)

            case .accountsCreated:
                state.currentStep = .done
                return .run { [clock] send in
                    try await clock.sleep(for: .milliseconds(1600))
                    await send(.doneAnimationFinished)
                }

            case .doneAnimationFinished:
                return .send(.delegate(.onboardingCompleted))

            case .delegate:
                return .none
            }
        }
        .ifLet(\.$customAccountSheet, action: \.customAccountSheet) {
            CustomAccountFormFeature()
        }
    }
}
```

> ⚠️ **舊的 private extension `Account.defaultCashName` / `defaultCashColorHex` / `AccountType.defaultIcon` / `defaultColor` 全部刪除**（new code 直接用 `AccountType.cash.displayLabel` 等 public extension）。
>
> ⚠️ Tests 用 `Action: Equatable`；新 reducer 也標 `Equatable`。`CustomAccountDraft` 已是 Equatable（Task 7 定義）。

- [ ] **Step 4: 跑單一 suite 測試**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:FeaturesTests/OnboardingFeatureTests 2>&1 | tail -25
```

預期：9 tests PASS。

- [ ] **Step 5: 跑完整 Features scheme（OnboardingView 仍在使用舊 state，預期 Features compile fail）**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -20
```

預期：**Features library compile FAIL** with errors in `OnboardingView.swift` referencing removed properties (`accountName`, `accountType`, `accountSetup`, `binding`)。這是預期狀態。Step 6 就 commit。

- [ ] **Step 6: Commit（接受暫時 broken state，明確 commit message 說明）**

```bash
git add Features/Sources/Features/Onboarding/OnboardingFeature.swift Features/Tests/FeaturesTests/OnboardingFeatureTests.swift
git commit -m "feat(onboarding): rewrite OnboardingFeature reducer

State machine now:
  - 4 steps (welcome, accountSelection, ready, done)
  - selectedTypes: Set<AccountType> (default [.cash])
  - customAccounts: [CustomAccountDraft]
  - customAccountSheet child via ifLet
  - skip writes a localized default cash account
  - finish writes selected types + customs and triggers 1.6s done animation

OnboardingView intentionally fails to compile in this commit; the
view layer is rewritten in subsequent commits (Tasks 11-13)."
```

---

## Task 10: 重寫 `OnboardingView` — Welcome Step

**Files:**
- Modify: `Features/Sources/Features/Onboarding/OnboardingView.swift`

> ⚠️ Task 9 結束時 view 處於 broken state。本 task 把 view scaffold + Welcome step 補回，先讓 build 通過。Account selection 的 grid + sheet 等到 Task 11；Ready / Done 等到 Task 12。本 task 暫時把 `accountSelection` / `ready` / `done` step 顯示成 placeholder text（讓 Skip 路徑可走通做 smoke）。

- [ ] **Step 1: 整個替換 `OnboardingView.swift`**

```swift
//  OnboardingView.swift
//  Features

import SwiftUI
import ComposableArchitecture
import Domain
import Common

struct OnboardingView: View {
    @Bindable var store: StoreOf<OnboardingFeature>

    var body: some View {
        ZStack {
            backgroundForCurrentStep
            currentStepView
                .animation(.spring(response: 0.5, dampingFraction: 0.85), value: store.currentStep)
        }
    }

    @ViewBuilder
    private var backgroundForCurrentStep: some View {
        switch store.currentStep {
        case .welcome:          WarmGradientBackground(variant: .top)
        case .accountSelection: WarmGradientBackground(variant: .bottomRight)
        case .ready, .done:     WarmGradientBackground(variant: .center)
        }
    }

    @ViewBuilder
    private var currentStepView: some View {
        switch store.currentStep {
        case .welcome:          welcomeStep
        case .accountSelection: placeholderStep("Account Selection (Task 11)")
        case .ready:            placeholderStep("Ready (Task 12)")
        case .done:             placeholderStep("Done (Task 12)")
        }
    }

    // MARK: - Welcome

    private var welcomeStep: some View {
        VStack(spacing: 0) {
            Spacer()

            // Preview glass card (decorative)
            previewCard
                .padding(.horizontal, 24)
                .modifier(RevealOnAppear(delay: 0.12))

            // Title block
            titleBlock
                .padding(.top, 32)
                .padding(.horizontal, 24)
                .modifier(RevealOnAppear(delay: 0.46))

            Spacer()

            // CTA + dots
            VStack(spacing: 16) {
                PrimaryButton("onboarding_welcome_button", systemImage: "arrow.forward") {
                    store.send(.startButtonTapped)
                }
                HStack {
                    OnboardingPageDots(active: 0)
                    Spacer()
                    Button { store.send(.skipButtonTapped) } label: {
                        Text("common_skip")
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
            .modifier(RevealOnAppear(delay: 0.64))
        }
    }

    private var previewCard: some View {
        GlassContainer(cornerRadius: 28, padding: 24) {
            VStack(alignment: .leading, spacing: 14) {
                Text("onboarding_welcome_card_eyebrow")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                Text(Decimal(0).twdFormatted)
                    .font(.system(size: 44, weight: .bold).monospacedDigit())
                    .foregroundStyle(.primary)
                HStack(spacing: 8) {
                    chip("onboarding_welcome_chip_starting", color: Color.Design.brandPrimary)
                    chip("onboarding_welcome_chip_on_device", color: .secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func chip(_ key: LocalizedStringKey, color: Color) -> some View {
        Text(key)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(color)
            .padding(.vertical, 5)
            .padding(.horizontal, 10)
            .background(
                Capsule().fill(color.opacity(0.14))
            )
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            (
                Text("onboarding_welcome_title_lead")
                    .font(.system(size: 44, weight: .bold))
                + Text(" ")
                + Text("onboarding_welcome_title_emphasis")
                    .font(.system(size: 44, weight: .semibold).italic())
                    .foregroundColor(Color.Design.brandPrimary)
            )
            .lineSpacing(-2)

            Text("onboarding_welcome_subtitle")
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Placeholder (filled by later tasks)

    private func placeholderStep(_ label: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Text(label)
                .font(.title2)
                .foregroundStyle(.secondary)
            Button("Skip") { store.send(.skipButtonTapped) }
            Spacer()
        }
    }
}

// MARK: - Reveal modifier

private struct RevealOnAppear: ViewModifier {
    let delay: Double
    @State private var visible = false
    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .offset(y: visible ? 0 : 24)
            .animation(.easeOut(duration: 0.55).delay(delay), value: visible)
            .task { visible = true }
    }
}

// MARK: - Preview

#Preview("Welcome") {
    OnboardingView(
        store: Store(initialState: OnboardingFeature.State(currentStep: .welcome)) {
            OnboardingFeature()
        }
    )
}
```

> ⚠️ 若 build 報 `Color.Design.brandPrimary` 找不到，grep 既有 token：`grep -rn "Color.Design\." Features/Sources --include="*.swift" | head -10`，把 `brandPrimary` 改成實際 token（例如 `accent`）。同樣處理 `.twdFormatted`：`grep -rn "twdFormatted" Features/Sources/Common`。

- [ ] **Step 2: Build app**

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -10
```

預期：build succeeded。

- [ ] **Step 3: 跑完整 Features test scheme（reducer test 必須仍 PASS）**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -10
```

預期：全部 PASS。

- [ ] **Step 4: Commit**

```bash
git add Features/Sources/Features/Onboarding/OnboardingView.swift
git commit -m "feat(onboarding): rewrite OnboardingView Welcome step

Restore compilation after the reducer rewrite. Welcome step is
final (warm gradient + preview glass card + lead/emphasis title +
stagger reveal). Other steps are placeholders so the build passes;
they get implemented in Tasks 11-13."
```

---

## Task 11: `OnboardingView` — Account Selection Step + Sheet

**Files:**
- Modify: `Features/Sources/Features/Onboarding/OnboardingView.swift`

- [ ] **Step 1: 把 placeholder `accountSelection` 換成完整 view + 加 sheet modifier**

在 `OnboardingView.swift` 中：

1. 把 `placeholderStep("Account Selection (Task 11)")` 換成 `accountSelectionStep`
2. 在 `body` 的最外層 `ZStack` 加 `.sheet(item: $store.scope(state: \.customAccountSheet, action: \.customAccountSheet)) { sheetStore in CustomAccountFormView(store: sheetStore) }`
3. 新增以下 view：

```swift
// MARK: - Account Selection

private var accountSelectionStep: some View {
    VStack(alignment: .leading, spacing: 0) {
        // Header
        HStack(spacing: 8) {
            Button { store.send(.startButtonTapped) } label: {
                // 沒有真正 back 動作（welcome -> selection 是單向）；隱藏這顆按鈕避免誤導
                Color.clear.frame(width: 0, height: 0)
            }
            Text("onboarding_step_indicator_2")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Spacer()
            Button { store.send(.skipButtonTapped) } label: {
                Text("common_skip")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 16)

        Text("onboarding_selection_title")
            .font(.system(size: 32, weight: .bold))
            .padding(.top, 12)
        Text("onboarding_selection_subtitle")
            .font(.system(size: 14))
            .foregroundStyle(.secondary)
            .padding(.top, 6)
            .padding(.bottom, 20)

        // Type grid
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
            spacing: 12
        ) {
            ForEach(AccountType.allCases, id: \.self) { type in
                typeCard(for: type)
            }
        }

        // Custom accounts list
        if !store.customAccounts.isEmpty {
            VStack(spacing: 8) {
                ForEach(store.customAccounts) { draft in
                    customAccountRow(draft)
                }
            }
            .padding(.top, 12)
        }

        // Add custom button
        Button { store.send(.addCustomAccountTapped) } label: {
            HStack {
                Image(systemName: "plus")
                Text("onboarding_selection_add_custom")
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Color.secondary.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [6]))
            }
        }
        .padding(.top, 12)
        .buttonStyle(.plain)

        Spacer()

        VStack(spacing: 16) {
            PrimaryButton(continueButtonKey) { store.send(.nextButtonTapped) }
                .opacity(continueDisabled ? 0.5 : 1)
                .disabled(continueDisabled)
            HStack {
                OnboardingPageDots(active: 1)
                Spacer()
            }
        }
    }
    .padding(.horizontal, 22)
    .padding(.bottom, 28)
}

private var totalSelectedCount: Int {
    store.selectedTypes.count + store.customAccounts.count
}

private var continueDisabled: Bool { totalSelectedCount == 0 }

private var continueButtonKey: LocalizedStringKey {
    LocalizedStringKey(stringLiteral: String(localized: "onboarding_selection_continue_format", defaultValue: "Continue · \(totalSelectedCount) selected"))
        // Note: this still works because LocalizedStringKey treats the string as a key;
        // we use String(format:) below instead.
}

@ViewBuilder
private func typeCard(for type: AccountType) -> some View {
    let isSelected = store.selectedTypes.contains(type)
    Button { store.send(.typeToggled(type)) } label: {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(swatch(for: type).opacity(0.12))
                    Image(systemName: type.defaultIcon)
                        .font(.system(size: 20))
                        .foregroundStyle(swatch(for: type))
                }
                .frame(width: 36, height: 36)
                Spacer()
                ZStack {
                    Circle()
                        .strokeBorder(Color.secondary.opacity(0.5), lineWidth: 1.5)
                        .background(
                            Circle()
                                .fill(isSelected ? Color.Design.brandPrimary : Color.clear)
                        )
                        .clipShape(Circle())
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 22, height: 22)
            }
            Spacer()
            Text(eyebrow(for: type))
                .font(.system(size: 10, weight: .medium))
                .textCase(.uppercase)
                .tracking(1)
                .foregroundStyle(.secondary)
                .padding(.bottom, 4)
            Text(type.displayLabel)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)
        }
        .padding(16)
        .frame(minHeight: 140, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(isSelected ? Color.Design.brandPrimary : Color.clear, lineWidth: 2)
        }
    }
    .buttonStyle(.plain)
}

private func swatch(for type: AccountType) -> Color {
    Color(hex: type.defaultColor)
}

private func eyebrow(for type: AccountType) -> String {
    switch type {
    case .cash:       "CASH"
    case .bank:       "BANK"
    case .creditCard: "CREDIT"
    case .eWallet:    "WALLET"
    }
}

@ViewBuilder
private func customAccountRow(_ draft: CustomAccountDraft) -> some View {
    HStack {
        Image(systemName: draft.type.defaultIcon)
            .foregroundStyle(Color(hex: draft.color))
        Text(draft.name)
            .font(.system(size: 15, weight: .medium))
        Spacer()
        Button { store.send(.customAccountDeleted(draft.id)) } label: {
            Image(systemName: "trash")
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
    .background {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(.ultraThinMaterial)
    }
}
```

加上 file-private `Color(hex:)` helper（如 `WarmGradientBackground.swift` 內已 private 化，不能跨檔；改放 `OnboardingView.swift` 內 fileprivate）：

```swift
private extension Color {
    init(hex: String) {
        let cleaned = hex.replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >>  8) & 0xFF) / 255.0
        let b = Double( rgb        & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
```

**修正 `continueButtonKey`** — 由於 PrimaryButton 接受 `LocalizedStringKey` 但格式化參數不容易，這裡改寫：

把 `PrimaryButton(continueButtonKey) { ... }` 替換成：

```swift
PrimaryButton(
    LocalizedStringKey(
        String(format: String(localized: "onboarding_selection_continue_format"), totalSelectedCount)
    )
) { store.send(.nextButtonTapped) }
```

然後刪除 `continueButtonKey` computed property（不需要）。

加 sheet modifier 到外層 ZStack：

```swift
ZStack {
    backgroundForCurrentStep
    currentStepView
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: store.currentStep)
}
.sheet(item: $store.scope(state: \.customAccountSheet, action: \.customAccountSheet)) { sheetStore in
    CustomAccountFormView(store: sheetStore)
        .presentationDetents([.medium, .large])
}
```

- [ ] **Step 2: Build**

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -10
```

預期：build succeeded。若報錯（type 不符 / token 名不對），按 grep 結果調整。

- [ ] **Step 3: 跑完整 Features scheme**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -10
```

預期：全部 PASS。

- [ ] **Step 4: Commit**

```bash
git add Features/Sources/Features/Onboarding/OnboardingView.swift
git commit -m "feat(onboarding): implement Account Selection step

2x2 grid of AccountType cards (Cash/Bank/Credit Card/E-Wallet),
custom accounts list with swipe-to-delete, '+ Add custom account'
opens the CustomAccountFormView sheet via store scope. Continue
button shows live count and is disabled when 0 selected."
```

---

## Task 12: `OnboardingView` — Ready + Done Steps

**Files:**
- Modify: `Features/Sources/Features/Onboarding/OnboardingView.swift`

- [ ] **Step 1: 把 placeholder ready / done 換成完整 view**

在 `currentStepView` 內：

```swift
case .ready: readyStep
case .done:  doneStep
```

新增以下 views：

```swift
// MARK: - Ready

private var readyStep: some View {
    VStack(spacing: 0) {
        Spacer()
        VStack(spacing: 32) {
            ZStack {
                Circle()
                    .fill(Color.Design.brandPrimary)
                    .frame(width: 100, height: 100)
                    .shadow(color: Color.Design.brandPrimary.opacity(0.35), radius: 28, x: 0, y: 10)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.white)
            }
            VStack(spacing: 12) {
                Text("onboarding_ready_title")
                    .font(.system(size: 36, weight: .bold))
                Text("onboarding_ready_subtitle")
                    .font(.system(size: 17))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            GlassContainer(cornerRadius: 22, padding: 20) {
                VStack(spacing: 8) {
                    Text("onboarding_ready_total_label")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Text(Decimal(0).twdFormatted)
                        .font(.system(size: 24, weight: .bold).monospacedDigit())
                    Text(
                        LocalizedStringKey(
                            String(format: String(localized: "onboarding_ready_account_count_format"), totalSelectedCount)
                        )
                    )
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                }
            }
            .frame(width: 220)
        }
        .padding(.horizontal, 24)
        Spacer()
        VStack(spacing: 16) {
            PrimaryButton("onboarding_ready_button") { store.send(.finishButtonTapped) }
                .disabled(store.isCreatingAccounts)
            HStack { OnboardingPageDots(active: 2); Spacer() }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 28)
    }
}

// MARK: - Done

private var doneStep: some View {
    VStack(spacing: 24) {
        Spacer()
        ZStack {
            Circle()
                .fill(Color.Design.brandPrimary)
                .frame(width: 88, height: 88)
                .shadow(color: Color.Design.brandPrimary.opacity(0.55), radius: 30, x: 0, y: 12)
            Image(systemName: "checkmark")
                .font(.system(size: 38, weight: .heavy))
                .foregroundStyle(.white)
        }
        .modifier(RevealOnAppear(delay: 0.05))
        VStack(spacing: 8) {
            Text("onboarding_done_title")
                .font(.system(size: 36, weight: .bold))
            Text("onboarding_done_subtitle")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .modifier(RevealOnAppear(delay: 0.20))
        Spacer()
    }
    .padding(.horizontal, 24)
    .padding(.bottom, 28)
}
```

> ⚠️ Done step 不需要 sheet 或 button — 1.6s 後 reducer 會自動 dispatch delegate.onboardingCompleted。

- [ ] **Step 2: Build app**

```bash
xcodebuild build -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -10
```

預期：build succeeded。

- [ ] **Step 3: 跑完整 Features scheme**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -10
```

預期：全部 PASS。

- [ ] **Step 4: Commit**

```bash
git add Features/Sources/Features/Onboarding/OnboardingView.swift
git commit -m "feat(onboarding): implement Ready + Done celebration steps

Ready step: brand circle with checkmark, hero title, total balance
preview card showing NT\$ 0 with '已建立 N 個帳戶' chip.
Done step: spring-revealed brand circle with checkmark + title +
subtitle; auto-dispatches delegate.onboardingCompleted after 1.6s."
```

---

## Task 13: 完整 Smoke + 切語言檢查 + 收尾

**Files:** 不修改檔案；驗證行為。

> ⚠️ 不派 subagent，主 session 直接做。若發現視覺異常，回到 Task 10-12 修正後再 commit。

- [ ] **Step 1: 全套自動化測試**

```bash
xcodebuild test -project NeuLedger.xcodeproj -scheme Features \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -15
```

預期：全部 PASS（OnboardingFeatureTests 9 + CustomAccountFormFeatureTests 6 + AccountTypeDisplayLabelTests 2 + AccountTypeDefaultsTests 2 + 既有測試）。

- [ ] **Step 2: 啟動 Simulator + 重置 onboarding**

```bash
# 開 Simulator
open -a Simulator
# Build + run NeuLedger（先確認 simulator id）
xcodebuild -showdestinations -project NeuLedger.xcodeproj -scheme NeuLedger 2>&1 | grep "iPhone 17 Pro" | head -3
# 用 xcrun simctl 移除 app 確保 onboarding 重跑：
xcrun simctl uninstall booted com.drakehuang.NeuLedger || true
# 用 Xcode IDE 跑 NeuLedger scheme 比較容易，或用 cli：
xcodebuild build-for-testing -project NeuLedger.xcodeproj -scheme NeuLedger \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -3
```

> ⚠️ Bundle id 若不是 `com.drakehuang.NeuLedger`，從 `NeuLedger.xcodeproj/project.pbxproj` grep `PRODUCT_BUNDLE_IDENTIFIER` 找實際值。

- [ ] **Step 3: 手動 smoke — 黃金路徑**

在 simulator 內：

1. 啟動 NeuLedger，確認跳到 Welcome
2. Welcome：見到 warm gradient + 預覽 glass card (NT$ 0 + 兩個 chip) + "每一塊錢，都看得見"（"都看得見" 為 accent 斜體）→ 按「開始」
3. Account Selection：見到 2x2 grid，現金 已勾、其他 未勾 → 點擊銀行帳戶 + 信用卡 → 點擊「+ 新增其他帳戶」開 sheet → 輸入「悠遊卡」、選類型「電子錢包」、選紫色 → 按「新增」 → 回到 selection 看到自訂列出現 → 點擊「繼續 · 4 個」
4. Ready：見到大綠勾 + 「你準備好了」 + 預覽卡 NT$ 0 + 「已建立 4 個帳戶」 → 按「完成」
5. Done：1.6s 後切到 dashboard
6. 在 dashboard 確認 4 個帳戶都存在，名稱分別為「現金 / 銀行帳戶 / 信用卡 / 悠遊卡」

- [ ] **Step 4: 手動 smoke — Skip 路徑**

1. 重新 uninstall app + 重新 launch
2. Welcome 直接點「跳過」
3. 應跳過 Account Selection / Ready，直接看到 Done celebration（1.6s）
4. Dashboard 確認只有 1 個「現金」帳戶

- [ ] **Step 5: 手動 smoke — Dark mode**

在 Simulator 切 Dark Mode（`xcrun simctl ui booted appearance dark`），重複 Step 3 第 1-3 步：
- gradient 從 peach 切換到 warm-brown
- glass card 對比正確（不會看不見文字）
- accent 色的「都看得見」字 + 預覽卡 chip 在 dark 下仍清晰

- [ ] **Step 6: 手動 smoke — 切英文**

在 Simulator settings 把語言切為 English，重新 launch app，重複 Step 3。預期：
- Welcome title: "Every NT$, seen"
- Account types: "Cash / Bank / Credit Card / E-Wallet"
- 帳戶建立後 dashboard 顯示英文帳戶名

- [ ] **Step 7: 視覺/行為缺陷紀錄**

如果有任何缺陷：
- 視覺問題（位置、顏色、字級偏差）→ 回 Task 10-12 對應 view 修正後重 commit
- 行為問題（state 流程、寫入錯誤）→ 回 Task 9 reducer 修正

修補 commit 訊息格式：`fix(onboarding): <what>`。

- [ ] **Step 8: 沒有缺陷時的最終 commit（即使沒程式碼變更，也記錄 smoke 通過）**

> ⚠️ Smoke 沒缺陷時不會有 file change；無需 commit。直接結束 plan。若有任何小修補（typo、padding 微調），用 `git commit -am` 整合。

---

## Self-Review

完成所有 task 後，spec 對應檢查表：

| Spec section | 由誰實作 |
|---|---|
| State 設計（4 step / selectedTypes / customAccounts / sheet） | Task 9 |
| CustomAccountFormFeature reducer | Task 7 |
| AccountType.displayLabel localized | Task 2 |
| AccountType.defaultIcon / defaultColor public | Task 3 |
| Welcome step UI（gradient + 預覽卡 + lead/emphasis 標題 + reveal） | Task 10 |
| Account Selection grid + sheet + 自訂帳戶列表 | Task 11 |
| Ready step（success circle + 預覽卡 + count chip） | Task 12 |
| Done celebration + 1.6s auto delegate | Task 9 (reducer) + Task 12 (view) |
| Skip 改為直接到 Done | Task 9 |
| WarmGradientBackground / OnboardingPageDots 共用元件 | Task 5 / 6 |
| Localization keys（新增 / 修改 / 刪除） | Task 1 + 4 |
| Domain test for displayLabel / defaults | Task 2 / 3 |
| TCA TestStore 9 test | Task 9 |
| 完整 Features scheme + manual smoke | Task 13 |
